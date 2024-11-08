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

//------------------------- Variables                    ----------------------------//
  //----------------------- Counters                     --------------------------//
    parameter         FRAMES_PER_ACTION = 5;  // Action delay
    logic     [31:0]  frames_cntr ;
    logic             end_of_frame;           // End of frame's active zone
  //----------------------- Accelerometr                 --------------------------//
    parameter     ACCEL_X_CORR = 8'd3;        // Accelerometer x correction
    parameter     ACCEL_Y_CORR = 8'd1;        // Accelerometer y correction
    wire   [7:0]  accel_data_x_corr  ;        // Accelerometer x corrected data
    wire   [7:0]  accel_data_y_corr  ;        // Accelerometer y corrected data
  //----------------------- Object (Stick)               --------------------------//

    logic  [9:0] ball_x;
    logic  [9:0] ball_y;

    logic signed [9:0] speed_x;
    logic signed [9:0] speed_y;

    parameter signed DECEL = 10'd1;

    wire        map_0_x_coll_out;
    wire        map_0_y_coll_out;
    wire [18:0] map_coll_read_address;
    wire        map_0_tex_out;
    wire [18:0] map_tex_read_address;
    
    //   0 1         X
    //  +------------->
    // 0|
    // 1|  P.<v,h>-> width
    //  |   |
    // Y|   |
    //  |   V heigh
    //  |
    //  V

    assign map_coll_read_address = ball_y * 800 + {8'b0, ball_x};
    assign map_tex_read_address = v_coord * 800 + {8'b0, h_coord};
    //assign map_read_address = v_coord * 800 + {8'b0, h_coord};
    map_0_x_rom map_0_x_rom (
      .addr   (map_coll_read_address),
      .data   (map_0_x_coll_out)
    );
    map_0_y_rom map_0_y_rom (
      .addr   (map_coll_read_address),
      .data   (map_0_y_coll_out)
    );
    map_0_tex_rom map_0_tex_rom (
      .addr   (map_tex_read_address),
      .data   (map_0_tex_out)
    );

    wire map_coll_x;
    wire map_coll_y;
    wire map_tex;

    assign map_coll_x = map_0_x_coll_out;
    assign map_coll_y = map_0_y_coll_out;
    assign map_tex = map_0_tex_out;
    //assign ver_collide = map_coll_x;
    //assign hor_collide = map_coll_y;
  
  // ----------------------------- ball movement --------------------- //

  always_ff @ ( posedge pixel_clk ) begin
    if ( !rst_n ) begin
      ball_x = 200;
      ball_y = 300;
      speed_x = 0;
      speed_y = 0;
    end
    else if ( end_of_frame ) begin
      if (map_coll_x)
        speed_x = -speed_x;
      if (map_coll_y)
        speed_y = -speed_y;

      ball_x = ball_x + speed_x;
      ball_y = ball_y + speed_y;
      if (button_l)
        speed_x = speed_x - 1;
      if (button_r)
        speed_x = speed_x + 1;
      if (button_u)
        speed_y = speed_y - 1;
      if (button_d)
        speed_y = speed_y + 1;

      if ( frames_cntr == 0 ) begin
        if (-DECEL <= speed_x && speed_x <= DECEL)
          speed_x = 0;
        if (-DECEL <= speed_y && speed_y <= DECEL)
          speed_y = 0;
        if (speed_x > 0)
          speed_x = speed_x - DECEL;
        else if (speed_x < 0)
          speed_x = speed_x + DECEL;
        if (speed_y > 0)
          speed_y = speed_y - DECEL;
        else if (speed_y < 0)
          speed_y = speed_y + DECEL;
      end

      if (speed_x > 10)
        speed_x = 10;
      if (speed_x < -10)
        speed_x = -10;
      if (speed_y > 10)
        speed_y = 10;
      if (speed_y < -10)
        speed_y = -10;
    end
  end


  // ----------------------------------- collision detection ------------------------ //

  //------------------------- End of Frame                 ----------------------------//
  // We recount game object once at the end of display counter //
  always_ff @( posedge pixel_clk ) begin
    if ( !rst_n )
      end_of_frame <= 1'b0;
    else
      end_of_frame <= (h_coord[9:0]==10'd799) && (v_coord==10'd599); // 799 x 599
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
      accel_x_end_of_frame <= 8'h0000000;
      accel_y_end_of_frame <= 8'h0000000;
    end
    else if ( end_of_frame && (frames_cntr == 0) ) begin
      accel_x_end_of_frame <= accel_data_x_corr;
      accel_y_end_of_frame <= accel_data_y_corr;
    end
  end
  // Accelerometr corrections
  assign accel_data_x_corr = accel_data_x + ACCEL_X_CORR;
  assign accel_data_y_corr = accel_data_y + ACCEL_Y_CORR;

//____________________________________________________________________________//

    logic draw_ball;

  always @ (posedge pixel_clk ) begin
    draw_ball = (h_coord - ball_x) * (h_coord - ball_x) + (v_coord - ball_y) * (v_coord - ball_y) < 100;
  end

//------------- RGB MUX outputs                                  -------------//
  assign  red      = (draw_ball ? 4'hf : (map_tex ? 4'hf : 4'h0));
  assign  green    = (draw_ball ? 4'hf : 4'h0);
  //assign  blue     = (draw_ball ? 4'hf : (map_tex ? 4'hf : 4'h0));
  assign  blue     = (draw_ball ? 4'hf : 4'h0);
  //assign  red     = (SW[0] ? 4'hf : 4'h0);
  //assign  green   = (SW[1] ? 4'hf : 4'h0);
  //assign  blue    = (SW[2] ? 4'hf : 4'h0);
//____________________________________________________________________________//
endmodule
