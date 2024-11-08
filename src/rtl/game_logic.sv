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

function logic signed [19:0] dist2;
//function logic signed [9:0] dist2;
  input logic signed [9:0] x1;
  input logic signed [9:0] y1;
  input logic signed [9:0] x2;
  input logic signed [9:0] y2;
begin
  //dist2 = {x1 - x2} * {x1 - x2} + {y1 - y2} * {y1 - y2};
  dist2 = abs10({x1 - x2}) * abs10({x1 - x2}) + abs10({y1 - y2}) * abs10({y1 - y2});
  //dist2 = {10'b0, x1 - x2} * {10'b0, x1 - x2} + {10'b0, y1 - y2} * {10'b0, y1 - y2};
end
endfunction

function logic signed [19:0] dotP;
  input logic signed [9:0] x1;
  input logic signed [9:0] y1;
  input logic signed [9:0] x2;
  input logic signed [9:0] y2;
begin
  dotP = x1 * x2 + y1 * y2;
end
endfunction

function logic signed [19:0] crossP;
  input logic signed [9:0] x1;
  input logic signed [9:0] y1;
  input logic signed [9:0] x2;
  input logic signed [9:0] y2;
begin
  crossP = x1 * y2 - y1 * x2;
end
endfunction

function logic signed [19:0] abs20;
  input logic signed [19:0] x;
begin
  abs20 = x < 0 ? -x : x;
end
endfunction

function logic signed [9:0] abs10;
  input logic signed [9:0] x;
begin
  abs10 = x < 0 ? -x : x;
end
endfunction


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
    
    logic [19:0] arrow_len2;
  
  // ----------------------------- ball movement --------------------- //

  always_ff @ ( posedge pixel_clk ) begin
    if ( !rst_n ) begin
      ball_x = 200;
      ball_y = 300;
      speed_x = 0;
      speed_y = 0;
      arrow_len2 = 0;
    end
    else if ( end_of_frame ) begin
      arrow_len2 = (speed_x * speed_x + speed_y * speed_y);
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


      // FIXME: normalize
      if (speed_x > 20)
        speed_x = 20;
      if (speed_x < -20)
        speed_x = -20;
      if (speed_y > 20)
        speed_y = 20;
      if (speed_y < -20)
        speed_y = -20;
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



//------------- RGB MUX outputs                                  -------------//

  logic               draw_ball;
  logic signed [9:0]  arrow_x;
  logic signed [9:0]  arrow_y;
  logic [11:0]        map_tex_color;
  logic               draw_arrow_length;
  logic [19:0]        triangle_square;
  logic               draw_arrow_direction;
  logic               draw_arrow;
  logic [11:0]        current_color;
  logic               draw_arrow_orientation;

  always @ (posedge pixel_clk ) begin
    draw_ball = dist2(h_coord, v_coord, ball_x, ball_y) < 100;
    //draw_ball = (h_coord - ball_x) * (h_coord - ball_x) + (v_coord - ball_y) * (v_coord - ball_y) < 100;

    arrow_x = speed_x;
    arrow_y = speed_y;

    map_tex_color = (map_tex ? 12'h0f0 : 12'h000);
    draw_arrow_length = dist2(h_coord, v_coord, ball_x, ball_y) < arrow_len2 * 4;
    triangle_square = abs20(crossP(ball_x           - h_coord, ball_y           - v_coord,
                                   ball_x + arrow_x - h_coord, ball_y + arrow_y - v_coord));
    draw_arrow_direction = (triangle_square * triangle_square / arrow_len2) < 16;
    draw_arrow_orientation = crossP(ball_x           - h_coord, ball_y           - v_coord,
                                    // ball_x + arrow_x - h_coord, ball_y + arrow_y - v_coord) < 0;
                                    v_coord - arrow_y - ball_y, ball_x + arrow_y - h_coord) < 0;

    draw_arrow = draw_arrow_length & draw_arrow_direction & draw_arrow_orientation;

    current_color = 
                    draw_arrow ? 12'hf00 :
                    draw_ball ? 12'hfff : 
                    map_tex_color;
  end

  assign red   = current_color[3:0];
  assign green = current_color[7:4];
  assign blue  = current_color[11:8];
  //assign  red      = (draw_ball ? 4'hf : (map_tex ? 4'hf : 4'h0));
  //assign  green    = (draw_ball ? 4'hf : 4'h0);
  //assign  blue     = (draw_ball ? 4'hf : 4'h0);
//____________________________________________________________________________//
endmodule
