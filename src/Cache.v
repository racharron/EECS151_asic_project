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

  reg clearing, prev_clearing;
  reg [5:0] clear_counter;

  wire cpu_req_is_write;
  wire in_hit, in_miss, next_state_is_miss;
  wire line_is_dirty;
  wire [1:0] current_dirty_block;
  wire saving_line, cpu_writing;

  reg line_present, previously_in_miss;
  reg [3:0] line_dirty_blocks;
  reg [TAG_WIDTH-1:0] line_tag;

  wire [WORD_ADDR_BITS-1:CACHE_ADDR_BITS+INDEX_WIDTH] tag, prev_tag;
  wire [WORD_ADDR_BITS-TAG_WIDTH-1:CACHE_ADDR_BITS] index, prev_index;
  wire [CACHE_ADDR_BITS-1:0] word, prev_word;
  wire [1:0] sram_lower, wordselect;

  //valid bits 
  wire meta_dout_present, meta_din_present;
  //dirty bits
  wire [3:0] meta_dout_dirty, meta_din_dirty;
  wire [TAG_WIDTH-1:0] meta_dout_tag, meta_din_tag;

  reg [1:0] state, next_state;
  //  The cache is not doing anything at the moment, and is open to requests
  localparam IDLE = 2'b00;
  //  The cache is checking the metadata.  If there is a cache hit,1+4+TAG_WIDTH then 
  localparam QUERYING = 2'b01;
  localparam CACHE_READ_MISS = 2'b10;
  localparam CACHE_WRITE_MISS = 2'b11;

  wire [3:0] data_wmask [4];
  wire meta_we; 
  wire [3:0] meta_wmask;
  wire data_we [4];
  reg [7:0] data_addr;
  wire [5:0] meta_addr;
  wire [CPU_WIDTH-1:0] meta_din;
  wire [CPU_WIDTH-1:0] data_din [4];
  wire [CPU_WIDTH-1:0] meta_dout;
  wire [CPU_WIDTH-1:0] data_dout [4];

  reg [1:0] current_cache_block;

  /// Since the SRAM is synchronous, if we want to be able to output the result the cycle that we
  /// are done getting a cache line, we need to save it outside of the SRAM so it can be accessed
  /// immediately.
  reg [CPU_WIDTH-1:0] async_cache;
  /// The CPU may change the requested address each cycle, so if there is a miss, we need to store the previous address.
  reg [WORD_ADDR_BITS-1:0] previous_address;

  assign cpu_req_is_write = |cpu_req_write;
  
  assign {sram_lower, wordselect} = word;
  assign {tag, index, word} = cpu_req_addr;
  assign {prev_tag, prev_index, prev_word} = previous_address;

  assign {meta_dout_present, meta_dout_dirty, meta_dout_tag} = meta_dout[0+:1+4+TAG_WIDTH];
  assign meta_din = {{(32-(1+4+TAG_WIDTH)){1'b0}}, meta_din_present, meta_din_dirty, meta_din_tag};

  assign data_addr = {in_miss ? prev_index : index, saving_line ? current_dirty_block : in_miss ? current_cache_block : sram_lower};
  assign meta_addr = in_miss ? prev_index : index;

  assign in_hit = (previously_in_miss && state == IDLE) || (meta_dout_present && meta_dout_tag == prev_tag && state == QUERYING);
  assign in_miss = state == CACHE_WRITE_MISS || state == CACHE_READ_MISS;
  assign next_state_is_miss = next_state == CACHE_WRITE_MISS || next_state == CACHE_READ_MISS;
  assign line_is_dirty = |line_dirty_blocks;
  assign current_dirty_block = line_dirty_blocks[0] ? 2'd0 : line_dirty_blocks[1] ? 2'd1 : line_dirty_blocks[2] ? 2'd2 : 2'd3;
  assign saving_line = line_is_dirty && state == CACHE_WRITE_MISS;
  assign cpu_writing = state == QUERYING && cpu_req_is_write && in_hit;

  assign cpu_resp_valid = in_hit;

  assign cpu_req_ready = (state == IDLE && !prev_clearing && !clearing) || (state == QUERYING && in_hit);

  assign cpu_resp_data = previously_in_miss ? async_cache : data_dout[prev_word[1:0]];

  assign mem_req_rw = saving_line;
  assign mem_req_data_valid = saving_line;
  assign mem_req_valid = in_miss;
  assign mem_req_addr = {tag, index, saving_line ? current_dirty_block : current_cache_block};
  assign mem_req_data_bits = {data_dout[3], data_dout[2], data_dout[1], data_dout[0]};
  assign mem_req_data_mask = 16'hFFFF;

  assign meta_wmask = 4'hF;
  assign meta_din_present = !reset;
  assign meta_we = (in_miss && mem_resp_valid) || cpu_writing;
  assign meta_din_tag = tag;
  
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin
      assign data_we[i] = cpu_writing ? wordselect == i[1:0] : state == CACHE_READ_MISS && mem_resp_valid;
      assign data_wmask[i] = cpu_writing ? cpu_req_write : 4'hF;
      assign data_din[i] = cpu_writing ? cpu_req_data : mem_resp_data[CPU_WIDTH*i+:CPU_WIDTH];
      assign meta_din_dirty[i] = cpu_writing ? wordselect == i[1:0] || meta_dout_dirty[i] : 1'b0;
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
    .we(meta_we || clearing),
    .wmask(meta_wmask),
    .addr(clearing ? clear_counter : meta_addr),
    .din(clearing ? 32'd0 : meta_din),
    .dout(meta_dout)
  );

  always @(*) begin
    next_state = state;
    if (!clearing) case (state)
      IDLE: begin
        if (cpu_req_valid && cpu_req_ready) begin
          next_state = QUERYING;
        end
      end
      QUERYING: begin
        if (in_hit) begin
          if (!cpu_req_valid || !cpu_req_ready) next_state = IDLE;
          if (cpu_writing) begin
          end
        end else begin
          if (cpu_req_is_write && line_is_dirty) begin
            next_state = CACHE_WRITE_MISS;
          end else begin
            next_state = CACHE_READ_MISS;
          end
        end
      end
      CACHE_READ_MISS: begin
        if (mem_resp_valid && current_cache_block == 2'b11) begin
          next_state = IDLE;
        end
      end
      CACHE_WRITE_MISS: begin
        if ({1'b0, line_dirty_blocks[0]} + {1'b0, line_dirty_blocks[1]} + {1'b0, line_dirty_blocks[2]} + {1'b0, line_dirty_blocks[3]} == 2'b01) begin
          next_state = CACHE_READ_MISS;
        end
      end 
    endcase
  end

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      current_cache_block <= 2'd0;
      clearing <= 1'b1;
      prev_clearing <= 1'b0;
      clear_counter <= 6'd0;
      line_dirty_blocks <= 4'd0;
      previously_in_miss <= 1'b0;
    end else if (clearing) begin
      if (clear_counter == 6'h3F && prev_clearing) begin
        clearing <= 1'b0;
      end
      clear_counter <= clear_counter + 6'd1;
      prev_clearing <= clearing;
    end else begin
      state <= next_state;
      prev_clearing <= clearing;
      if (next_state == QUERYING) previous_address <= cpu_req_addr;
      previously_in_miss <= in_miss;
      if (state == QUERYING && next_state_is_miss) begin
        current_cache_block <= 2'd0;
        line_present <= meta_dout_present;
        line_dirty_blocks <= meta_dout_dirty;
        line_tag <= meta_dout_tag;
      end
      if (state == CACHE_READ_MISS && mem_resp_valid) begin
          current_cache_block <= current_cache_block + 2'd1;
          if (current_cache_block == sram_lower) begin
            async_cache <= data_din[prev_word[1:0]];
          end
      end
    end
  end

endmodule
