const std = @import("std");
const assert = std.debug.assert;
const rand = std.crypto.random;
const rl = @cImport({
    @cInclude("raylib.h");
});

// Window width and height
const WIDTH: u16 = 800;
const HEIGHT: u16 = 500;

// general player width and height
const PLAYER_WIDTH: i16 = 50;
const PLAYER_HEIGHT: i16 = 100;
const WALL_OFFSET: i16 = 5;

const PlayerType = enum {
    HUMAN,
    IA,
};

const PlayerSide = enum {
    LEFT,
    RIGHT,
};

const Vector2D = struct { y: i32, x: i32 };

// player?
const Player = struct {
    width: i16,
    height: i16,
    position: Vector2D,
    type: PlayerType,

    const Self = @This();

    pub fn init(playerType: PlayerType, playerSide: PlayerSide) Self {
        return .{ .type = playerType, .width = PLAYER_WIDTH, .height = PLAYER_HEIGHT, .position = switch (playerSide) {
            .RIGHT => .{ .x = (WIDTH - PLAYER_WIDTH) - WALL_OFFSET, .y = (HEIGHT - PLAYER_HEIGHT) / 2 },
            else => .{ .x = WALL_OFFSET, .y = (HEIGHT - PLAYER_HEIGHT) / 2 },
        } };
    }

    pub fn draw(self: *const Self) void {
        rl.DrawRectangle(@as(c_int, self.position.x), @as(c_int, self.position.y), @as(c_int, self.width), @as(c_int, self.height), rl.WHITE);
    }

    pub fn move(self: *Self) void {
        switch (self.type) {
            .HUMAN => self.manualMove(),
            else => self.iaMove(),
        }
    }

    fn manualMove(self: *Self) void {
        if (rl.IsKeyDown(rl.KEY_S) and self.position.y < (HEIGHT - PLAYER_HEIGHT)) {
            self.position.y += 10;
        }

        if (rl.IsKeyDown(rl.KEY_W) and self.position.y > 0) {
            self.position.y -= 10;
        }
    }

    fn iaMove(self: *Self) void {
        if (rl.IsKeyDown(rl.KEY_J) and self.position.y < (HEIGHT - PLAYER_HEIGHT)) {
            self.position.y += 10;
        }

        if (rl.IsKeyDown(rl.KEY_K) and self.position.y > 0) {
            self.position.y -= 10;
        }
    }
};

// ball ?
const Ball = struct {
    radius: f32,
    position: Vector2D,
    direction: struct { x: i16, y: i16 },

    const Self = @This();

    pub fn init() Self {
        const x_random_dir = rand.intRangeAtMost(u16, 0, 10);
        const y_random_dir = rand.intRangeAtMost(u16, 0, 10);
        return .{ .position = .{ .x = WIDTH / 2, .y = HEIGHT / 2 }, .radius = 10, .direction = .{ .x = if (x_random_dir >= 5) 3 else -3, .y = if (y_random_dir >= 5) 3 else -3 } };
    }

    pub fn draw(self: *const Self) void {
        rl.DrawCircle(@as(c_int, self.position.x), @as(c_int, self.position.y), self.radius, rl.RAYWHITE);
    }

    pub fn move(self: *Self, p1: *const Player, p2: *const Player) void {
        if (self.check_collision(p1) or self.check_collision(p2)) {
            self.direction.x *= -1;
        }

        if (self.position.y <= 0) {
            self.direction.y *= -1;
        }

        if (self.position.y > HEIGHT) {
            self.direction.y *= -1;
        }

        self.position.x += self.direction.x;
        self.position.y += self.direction.y;

        // if we get out of bound, crash
        assert(self.position.y >= -10);
        assert(self.position.y < HEIGHT + 10);
    }

    fn check_collision(self: *const Self, player: *const Player) bool {
        const closestX = @max(player.position.x, @min(self.position.x, player.position.x + player.width));
        const closestY = @max(player.position.y, @min(self.position.y, player.position.y + player.height));
        const dx = self.position.x - closestX;
        const dy = self.position.y - closestY;
        const r2: i32 = @intFromFloat(self.radius * self.radius);
        return ((dx * dx) + (dy * dy)) <= r2;
    }
};

var player1: ?Player = null;
var player2: ?Player = null;
var ball: ?Ball = null;

fn onSetup() void {
    player1 = Player.init(PlayerType.HUMAN, PlayerSide.LEFT);
    player2 = Player.init(PlayerType.IA, PlayerSide.RIGHT);
    ball = Ball.init();
}

fn onUpdate() void {
    assert(player1 != null);
    assert(player2 != null);
    assert(ball != null);

    // draw
    player1.?.draw();
    player2.?.draw();
    ball.?.draw();

    // move
    player1.?.move();
    player2.?.move();
    ball.?.move(&player1.?, &player2.?);

    if (ball.?.position.x < 0 or ball.?.position.x > WIDTH) {
        restart();
    }
}

fn restart() void {
    onDestroy();
    rl.ClearBackground(rl.BLACK);
    onSetup();
}

fn onDestroy() void {
    player1 = null;
    player2 = null;
    ball = null;
}

pub fn main() !void {
    rl.InitWindow(WIDTH, HEIGHT, "Ping Pong");
    rl.SetTargetFPS(60);
    defer {
        onDestroy();
        rl.CloseWindow();
    }

    onSetup();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);
        onUpdate();
        rl.EndDrawing();
    }
}
