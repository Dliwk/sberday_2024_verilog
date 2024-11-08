// vim: set ts=2 sts=2 sw=2 ai et:
// vim: set mouse=a:

module game_logic (
  //--------- Clock & Resets                     --------//
    input  wire           pixel_clk ,  // Pixel clock 36 MHz
    input  wire           rst_n     ,  // Active low synchronous reset
  //--------- Buttons                            --------//
    input  wire           button_c  ,
    input  wire           button_u  ,
    input  wire           button_d  ,
    input  wire           button_r  ,
    input  wire           button_l  ,
  //--------- Accelerometer                      --------//
    input  wire  [7:0]    accel_data_x         ,
    input  wire  [7:0]    accel_data_y         ,
    output logic [7:0]    accel_x_end_of_frame ,
    output logic [7:0]    accel_y_end_of_frame ,
  //--------- Pixcels Coordinates                --------//
    input  wire  [9:0]   h_coord   ,
    input  wire  [9:0]   v_coord   ,
  //--------- VGA outputs                        --------//
    output wire  [3:0]    red       ,  // 4-bit color output
    output wire  [3:0]    green     ,  // 4-bit color output
    output wire  [3:0]    blue      ,  // 4-bit color output
  //--------- Switches for background colour     --------//
    input  wire  [2:0]    SW  
);

integer i;
integer j;

//------------------------- Variables                    ----------------------------//
  //----------------------- Counters                     --------------------------//
    parameter         FRAMES_PER_ACTION = 2;  // Action delay
    logic     [31:0]  frames_cntr ;
    logic             end_of_frame;           // End of frame's active zone
  //----------------------- Accelerometr                 --------------------------//
    parameter     ACCEL_X_CORR = 8'd3;        // Accelerometer x correction
    parameter     ACCEL_Y_CORR = 8'd1;        // Accelerometer y correction
    wire   [7:0]  accel_data_x_corr  ;        // Accelerometer x corrected data
    wire   [7:0]  accel_data_y_corr  ;        // Accelerometer y corrected data
  //----------------------- Object (Stick)               --------------------------//

    wire  [9:0] ball_x;
    wire  [9:0] ball_y;

    // Define cell size
    parameter CELL_SIZE = 20;
  
    // Calculate current cell position
    wire [9:0] cell_col = h_coord / CELL_SIZE;
    wire [9:0] cell_row = v_coord / CELL_SIZE;
  
    // Define 2D array for cell colors
    // Assuming a maximum of 40x30 cells for 800x600 resolution
    reg [11:0] cell_colors [0:39][0:29]; // 4 bits for R, G, B each


    
    //   0 1         X
    //  +------------->
    // 0|
    // 1|  P.<v,h>-> width
    //  |   |
    // Y|   |
    //  |   V heigh
    //  |
    //  V
//------------------------- End of Frame                 ----------------------------//
  // We recount game object once at the end of display counter //
  always_ff @( posedge pixel_clk ) begin
    if ( !rst_n )
      end_of_frame <= 1'b0;
    else
      end_of_frame <= (h_coord == 10'd799) && (v_coord == 10'd599); // 799 x 599
  end
  always_ff @( posedge pixel_clk ) begin
    if ( !rst_n )
      frames_cntr <= 0;
    else if ( frames_cntr == FRAMES_PER_ACTION )
      frames_cntr <= 0;
    else if (end_of_frame)
      frames_cntr <= frames_cntr + 1;
  end

//------------------------- Accelerometr at the end of frame-------------------------//
  always @ ( posedge pixel_clk ) begin
    if ( !rst_n ) begin
      accel_x_end_of_frame <= 8'd0;
      accel_y_end_of_frame <= 8'd0;
    end
    else if ( end_of_frame && (frames_cntr == 0) ) begin
      accel_x_end_of_frame <= accel_data_x_corr;
      accel_y_end_of_frame <= accel_data_y_corr;
      
      for (i = 0; i < 40; i = i + 1) begin
        for (j = 0; j < 30; j = j + 1) begin
          cell_colors[i][j][11:8] = (accel_x_end_of_frame > i*6) ? 4'h0 : 4'h0; // Red
          cell_colors[i][j][7:4]  = (accel_y_end_of_frame > j*10) ? 4'h0 : 4'h0; // Green
          cell_colors[i][j][3:0]  = 4'h0; // Blue
        end
      end
    end
  end
  // Accelerometr corrections
  assign accel_data_x_corr = accel_data_x + ACCEL_X_CORR;
  assign accel_data_y_corr = accel_data_y + ACCEL_Y_CORR;

//____________________________________________________________________________//

//------------- RGB MUX outputs based on cell colors              -------------//
  wire [11:0] current_cell_color = cell_colors[cell_col][cell_row];

  assign red   = current_cell_color[11:8];
  assign green = current_cell_color[7:4];
  assign blue  = current_cell_color[3:0];
//____________________________________________________________________________//
  
endmodule
