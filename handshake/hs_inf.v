module hs_inf #(
    parameter WIDTH = 8,   //DATA_WIDTH
    parameter STAGE = 3    //PIPE_STAGE
)(
    input                   clk     ,
    input                   rst_n   ,
// UP
    output                  o_ready ,
    input                   i_valid ,
    input  [WIDTH-1:0]      i_data  ,
// DOWN
    input                   i_ready ,
    output                  o_valid ,
    output [WIDTH-1:0]      o_data   
);

reg    [STAGE-1:0]            valid_r         ;
wire   [STAGE-1:0]            ready_wire      ;
reg    [WIDTH*STAGE-1:0]      data_r          ;   //shift to simulate pipeline

reg                           valid_down_buff ;
reg    [WIDTH-1:0]            data_down_buff  ;

reg                           ready_up_buff   ;
reg                           valid_up_buff   ;
reg    [WIDTH-1:0]            data_up_buff    ;
wire                          buff_up_en      ;


wire                          valid_temp      ;
wire   [WIDTH-1:0]            data_temp       ;



//-----------valid_down_buff----------------//
always @(posedge clk) begin                 
    if (!rst_n)
        valid_down_buff <= 0;
    else if (ready_wire[STAGE-1])
        valid_down_buff <= valid_r[STAGE-1];  
end
assign o_valid = valid_down_buff;

//-----------data_down_buff----------------//
always @(posedge clk) begin
    if (ready_wire[STAGE-1] && valid_r[STAGE-1])
        data_down_buff <= data_r[STAGE*WIDTH-1-:WIDTH];
end
assign o_data = data_down_buff;

//----------ready_up_buff-----------------//
assign buff_up_en = i_valid & ready_up_buff & (~ready_wire[0]);     //The next level of the pipeline is not ready

always @(posedge clk) begin
    if (!rst_n)
        valid_up_buff <= 0;
    else
        valid_up_buff <= valid_up_buff ? ~ready_wire[0] : buff_up_en;  
end


always @(posedge clk) begin
    if (!rst_n)
         ready_up_buff <= 0;
    else
         ready_up_buff <= ready_wire[0] || (~valid_up_buff && ~buff_up_en);  
end
assign o_ready = ready_up_buff;

always @(posedge clk) begin
    if (buff_up_en)
        data_up_buff <= i_data;
end

assign valid_temp = ready_up_buff ? i_valid : valid_up_buff;
assign data_temp = ready_up_buff ? i_data : data_up_buff;

//---------------------------------------
assign ready_wire[STAGE-1] = i_ready || ~o_valid; 

always @(posedge clk) begin
    if (!rst_n)
        valid_r[0] <= 0;
    else if (ready_wire[0])
        valid_r[0] <= valid_temp;
end

always @(posedge clk) begin                         
    if (ready_wire[0] & valid_temp)
        data_r[WIDTH-1:0] <= data_temp;    
end

generate
    genvar i;
        for (i=0; i<STAGE-1; i=i+1) begin: READY_LOOP
            assign ready_wire[i] = ready_wire[i+1] || ~valid_r[i+1];
        end
endgenerate

generate
    genvar j;
        for (j=1; j<STAGE; j=j+1) begin: VALID_LOOP
            always @(posedge clk) begin
                if (!rst_n)
                    valid_r[j] <= 0;
                else if (ready_wire[j-1])
                    valid_r[j] <= valid_r[j-1];   
            end
        end  
endgenerate

generate
    genvar n;
        for (n=1; n<STAGE; n=n+1) begin: DATA_LOOP
            always @(posedge clk) begin
                if (ready_wire[n-1] & valid_r[n-1])
                    data_r[(n+1)*WIDTH-1-:WIDTH] <= data_r[n*WIDTH-1-:WIDTH];
            end
        end
endgenerate

endmodule