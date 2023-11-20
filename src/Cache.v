`include "util.vh"
`include "const.vh"

module cache #
(
  parameter LINES = 64,
  //  32
  parameter CPU_WIDTH = `CPU_INST_BITS,
  //  Number of bits required to address a word: 30
  parameter WORD_ADDR_BITS = `CPU_ADDR_BITS-`ceilLog2(`CPU_INST_BITS/8)
)
(
  input clk,
  input reset,

  input                       cpu_req_valid,
  output                      cpu_req_ready,
  input [WORD_ADDR_BITS-1:0]  cpu_req_addr,
  input [CPU_WIDTH-1:0]       cpu_req_data,
  input [3:0]                 cpu_req_write,

  output                      cpu_resp_valid,
  output [CPU_WIDTH-1:0]      cpu_resp_data,

  output                      mem_req_valid,
  input                       mem_req_ready,
  //  [29:2]
  output [WORD_ADDR_BITS-1:`ceilLog2(`MEM_DATA_BITS/CPU_WIDTH)] mem_req_addr,
  output                           mem_req_rw,
  output                           mem_req_data_valid,
  input                            mem_req_data_ready,
  output [`MEM_DATA_BITS-1:0]      mem_req_data_bits,
  // byte level masking
  output [(`MEM_DATA_BITS/8)-1:0]  mem_req_data_mask,

  input                       mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]  mem_resp_data
);

  localparam CACHE_LINE_SIZE = 512;
  localparam INDEX_WIDTH = `ceilLog2(LINES);
  //  The number of bits required to get a word from a cache line
  localparam CACHE_ADDR_BITS = 4;
  localparam TAG_WIDTH = WORD_ADDR_BITS - INDEX_WIDTH - CACHE_ADDR_BITS; 

  wire cpu_req_is_write;
  wire in_miss, next_state_is_miss;
  wire line_is_dirty;
  wire [1:0] current_dirty_cell;
  wire saving_line, cpu_writing;

  wire [WORD_ADDR_BITS-1:CACHE_ADDR_BITS+INDEX_WIDTH] tag;
  wire [WORD_ADDR_BITS-TAG_WIDTH:CACHE_ADDR_BITS] index;
  wire [CACHE_ADDR_BITS-1:0] word;
  wire [1:0] sram_lower, wordselect;

  //valid bits 
  wire meta_dout_present, meta_din_present;
  //dirty bits
  wire [3:0] meta_dout_dirty;
  reg [3:0]  meta_din_dirty;
  wire [TAG_WIDTH-1:0] meta_dout_tag, meta_din_tag;

  reg [1:0] state, next_state;
  //  The cache is not doing anything at the moment, and is open to requests
  localparam IDLE = 2'b00;
  //  The cache is checking the metadata.  If there is a cache hit, then 
  localparam QUERYING = 2'b01;
  localparam CACHE_READ_MISS = 2'b10;
  localparam CACHE_WRITE_MISS = 2'b11;

  reg waiting_on_mem;

  wire [3:0] meta_wmask;
  wire [3:0] data_wmask [4];
  wire meta_we; 
  wire data_we [4];
  reg [7:0] data_addr;
  wire [5:0] meta_addr;
  wire [CPU_WIDTH-1:0] meta_din;
  wire [CPU_WIDTH-1:0] data_din [4];
  wire [CPU_WIDTH-1:0] meta_dout;
  wire [CPU_WIDTH-1:0] data_dout [4];

  reg [1:0] current_sram_cell;

  assign cpu_req_is_write = |cpu_req_write;
  
  assign {sram_lower, wordselect} = word;
  assign {tag, index, word} = cpu_req_addr;

  assign {meta_dout_present, meta_dout_dirty, meta_dout_tag} = meta_dout;
  assign meta_din = {meta_din_present, meta_din_dirty, meta_din_tag};

  assign data_addr = {index, saving_line ? current_dirty_cell : next_state_is_miss ? current_sram_cell : sram_lower};
  assign meta_addr = index;

  assign in_hit = meta_dout_present && meta_dout_tag == tag || state == QUERYING;
  assign in_miss = state == CACHE_WRITE_MISS || state == CACHE_READ_MISS;
  assign next_state_is_miss = next_state == CACHE_WRITE_MISS || next_state == CACHE_READ_MISS;
  assign line_is_dirty = |meta_dout_dirty;
  assign current_dirty_cell = meta_dout_dirty[0] ? 0 : meta_dout_dirty[1] ? 1 : meta_dout_dirty[2] ? 2 : 3;
  assign saving_line = line_is_dirty && state == CACHE_WRITE_MISS;
  assign cpu_writing = state == QUERYING && cpu_req_is_write && in_hit;

  assign cpu_resp_valid = in_hit;

  assign cpu_req_ready = state == IDLE/* || (state == QUERYING && in_hit)*/;

  assign cpu_resp_data = data_dout[word];

  assign mem_req_rw = saving_line;
  assign mem_req_data_valid = saving_line;
  assign mem_req_valid = in_miss && next_state_is_miss && !waiting_on_mem;
  assign mem_req_addr = saving_line ? {tag, index, current_dirty_cell} : {tag, index, current_sram_cell};
  assign mem_req_data_bits = {data_dout[3], data_dout[2], data_dout[1], data_dout[0]};
  assign mem_req_data_mask = 16'hFFFF;

  assign meta_wmask = 4'hF;
  assign meta_din_present = 1;
  assign meta_we = (in_miss && !next_state_is_miss) || cpu_writing;
  assign meta_din_tag = tag;
  
  genvar i;
  generate
    for (i = 1; i < 4; i = i + 1) begin
      assign data_we[i] = (cpu_writing && word == i) || waiting_on_mem && mem_resp_valid;
      assign data_wmask[i] = cpu_writing ? cpu_req_write : 4'hF;
      assign data_din[i] = cpu_writing ? cpu_req_data : mem_resp_data[CPU_WIDTH*i+:CPU_WIDTH];
    end
  endgenerate

  sram22_256x32m4w8 sramData[3:0] (
    .clk(clk),
    .we(data_we),
    .wmask(data_wmask),
    .addr(data_addr),
    .din(data_din),
    .dout(data_dout)
  );

  // {valid, tag}
  sram22_64x32m4w8 sramMeta (
    .clk(clk),
    .we(meta_we),
    .wmask(meta_wmask),
    .addr(meta_addr),
    .din(meta_din),
    .dout(meta_dout)
  );

  always @(*) begin
    next_state = state;
    meta_din_dirty = meta_dout_dirty;
    case (state)
      IDLE: begin
        if (cpu_req_valid && cpu_req_ready) begin
          next_state = QUERYING;
        end
      end
      QUERYING: begin
        if (in_hit) begin
          //  Possible optimization: if cpu_req_valid, then do not leave QUERYING
          next_state = IDLE;
          if (cpu_writing) begin
            meta_din_dirty = meta_dout_dirty | (4'b0001 << word);
          end
        end else begin
          if (cpu_req_is_write) begin
            next_state = CACHE_WRITE_MISS;
          end else begin
            next_state = CACHE_READ_MISS;
          end
        end
      end
      CACHE_READ_MISS: begin
        if (mem_resp_valid && current_sram_cell == 2'b11) begin
          next_state = QUERYING;
        end
      end
      CACHE_WRITE_MISS: begin
        if (line_is_dirty) begin
          meta_din_dirty = meta_dout_dirty & ~(4'b0001 << current_dirty_cell);
        end
        if (!line_is_dirty && current_sram_cell == 2'b11) begin
          next_state = QUERYING;
        end
      end 
    endcase
  end

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      current_sram_cell <= 2'd0;
      waiting_on_mem <= 0;
    end else begin
      state <= next_state;
      if (state == QUERYING && next_state_is_miss) begin
        current_sram_cell <= 2'd0;
        waiting_on_mem <= 0;
      end 
      if (in_miss && next_state_is_miss) begin
        if (waiting_on_mem && mem_resp_valid) begin
          waiting_on_mem = 0;
          current_sram_cell <= current_sram_cell + 1;
        end else if (!waiting_on_mem && mem_req_ready) begin
          waiting_on_mem = 1;
        end
      end
    end
  end

endmodule
