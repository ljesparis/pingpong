const std = @import("std");
const assert = std.debug.assert;
const rand = std.crypto.random;
const rl = @cImport({
    @cInclude("raylib.h");
});

const Map = struct {
    width: f32,
    height: f32,
    x: f32,
    y: f32,

    const Self = @This();

    pub fn init(width: f32, height: f32, x: f32, y: f32) Self {
        return .{
            .width = width,
            .height = height,
            .x = x,
            .y = y,
        };
    }

    pub fn draw(self: *const Self) void {
        rl.DrawRectangleLines(
            @intFromFloat(self.x),
            @intFromFloat(self.y),
            @intFromFloat(self.width),
            @intFromFloat(self.height),
            rl.RAYWHITE,
        );
    }
};

const PlayerType = enum {
    HUMAN,
    IA,
};

const PlayerSide = enum {
    LEFT,
    RIGHT,
};

// player?
const Player = struct {
    width: f32,
    height: f32,
    x: f32,
    y: f32,
    type: PlayerType,

    _map: *const Map,

    const Self = @This();

    pub fn init(
        playerType: PlayerType,
        playerSide: PlayerSide,
        width: f32,
        height: f32,
        _map: *const Map,
    ) Self {
        const x: f32 = switch (playerSide) {
            .RIGHT => _map.width - width,
            else => width - _map.x,
        };
        const y: f32 = ((_map.height - height) / FAMOUS_2) + _map.y;
        return .{
            ._map = _map,
            .type = playerType,
            .width = width,
            .height = height,
            .x = x,
            .y = y,
        };
    }

    pub fn draw(self: *const Self) void {
        rl.DrawRectangle(
            @intFromFloat(self.x),
            @intFromFloat(self.y),
            @intFromFloat(self.width),
            @intFromFloat(self.height),
            rl.WHITE,
        );
    }

    pub fn move(self: *Self) void {
        switch (self.type) {
            .HUMAN => self.manualMove(),
            else => self.iaMove(),
        }
    }

    fn manualMove(self: *Self) void {
        if (rl.IsKeyDown(rl.KEY_S) and self.y < (self._map.height + self._map.y - self.height)) {
            self.y += 10;
        }

        if (rl.IsKeyDown(rl.KEY_W) and self.y > self._map.y) {
            self.y -= 10;
        }
    }

    fn iaMove(self: *Self) void {
        if (rl.IsKeyDown(rl.KEY_J) and self.y < (self._map.height + self._map.y - self.height)) {
            self.y += 10;
        }

        if (rl.IsKeyDown(rl.KEY_K) and self.y > self._map.y) {
            self.y -= 10;
        }
    }
};

// ball ?
const Ball = struct {
    radius: f32,
    x: f32,
    y: f32,
    velocity: struct { x: f32, y: f32 },
    _p1: *const Player,
    _p2: *const Player,
    _map: *const Map,

    const Self = @This();

    const BallError = error{ TouchedRightWall, TouchedLeftWall };

    pub fn init(radius: f32, _map: *const Map, p1: *const Player, p2: *const Player) Self {
        const x_random_dir: f32 = if (rand.intRangeAtMost(u16, 0, 10) >= 5) 3 else -3;
        const y_random_dir: f32 = if (rand.intRangeAtMost(u16, 0, 10) >= 5) 3 else -3;
        return .{
            ._p1 = p1,
            ._p2 = p2,
            ._map = _map,
            .x = _map.width / FAMOUS_2,
            .y = (_map.height + _map.y) / FAMOUS_2,
            .radius = radius,
            .velocity = .{ .x = x_random_dir, .y = y_random_dir },
        };
    }

    pub fn draw(self: *const Self) void {
        rl.DrawCircle(
            @intFromFloat(self.x),
            @intFromFloat(self.y),
            self.radius,
            rl.RAYWHITE,
        );
    }

    pub fn move(self: *Self) BallError!void {
        if (self.x - self.radius <= self._map.x) {
            return BallError.TouchedLeftWall;
        }

        if (self.x + self.radius >= self._map.x + self._map.width) {
            return BallError.TouchedRightWall;
        }

        if (self.hasCollideWithAnyPlayer()) {
            self.velocity.x *= -1;
        }

        if (self.y - self.radius <= self._map.y) {
            self.velocity.y *= -1;
        }

        if (self.y + self.radius > self._map.height + self._map.y) {
            self.velocity.y *= -1;
        }

        self.x += self.velocity.x;
        self.y += self.velocity.y;

        // if we get out of bound, crash
        assert(self.y > self._map.y);
        assert(self.y < self._map.height + self._map.y);
    }

    fn hasCollideWithAnyPlayer(self: *const Self) bool {
        return self.checkCollision(self._p1) or self.checkCollision(self._p2);
    }

    fn checkCollision(self: *const Self, obj: anytype) bool {
        const closestX = std.math.clamp(self.x, obj.x, obj.x + obj.width);
        const closestY = std.math.clamp(self.y, obj.y, obj.y + obj.height);
        const dx = self.x - closestX;
        const dy = self.y - closestY;
        return (dx * dx) + (dy * dy) <= self.radius * self.radius;
    }
};

const Score = struct {
    x: i32,
    y: i32,
    value: i32,

    const Self = @This();

    pub fn init(x: i32, y: i32, value: i32) Self {
        return .{
            .x = x,
            .y = y,
            .value = value,
        };
    }

    pub fn increment(self: *Self) void {
        self.value += 1;
    }

    pub fn draw(self: *const Self) !void {
        var buffer: [32]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "Score: {}\x00", .{self.value});
        const x: c_int = @as(c_int, self.x);
        const y: c_int = @as(c_int, self.y);
        rl.DrawText(
            text.ptr,
            x,
            y,
            16,
            rl.RAYWHITE,
        );
    }
};

// Window width and height
const WIDTH: u16 = 800;
const HEIGHT: u16 = 500;
const FAMOUS_2: f32 = 2.0;

// general player width and height
const PLAYER_WIDTH: i16 = 30;
const PLAYER_HEIGHT: i16 = 100;

var player1: ?Player = null;
var player2: ?Player = null;
var ball: ?Ball = null;
var map: ?Map = null;
var l_score: ?Score = null;
var r_score: ?Score = null;

fn initializePlayersAndBall() void {
    player1 = Player.init(PlayerType.HUMAN, PlayerSide.LEFT, PLAYER_WIDTH, PLAYER_HEIGHT, &map.?);
    player2 = Player.init(PlayerType.IA, PlayerSide.RIGHT, PLAYER_WIDTH, PLAYER_HEIGHT, &map.?);
    ball = Ball.init(10, &map.?, &player1.?, &player2.?);
}

fn onSetup() void {
    // lets center the map
    map = Map.init(WIDTH - 20, HEIGHT - 100, 10, 50);
    l_score = Score.init(5, 4, 0);
    r_score = Score.init(WIDTH - 75, 4, 0);

    initializePlayersAndBall();
}

fn restart() void {
    destroyPlayersAndBall();
    rl.ClearBackground(rl.BLACK);
    initializePlayersAndBall();
}

fn onUpdate() !void {
    assert(player1 != null);
    assert(player2 != null);
    assert(ball != null);
    assert(map != null);

    // draw
    map.?.draw();
    try l_score.?.draw();
    try r_score.?.draw();
    player1.?.draw();
    player2.?.draw();
    ball.?.draw();

    // move
    player1.?.move();
    player2.?.move();
    ball.?.move() catch |err| {
        restart();
        switch (err) {
            Ball.BallError.TouchedLeftWall => r_score.?.increment(),
            else => l_score.?.increment(),
        }
    };
}

fn destroyPlayersAndBall() void {
    player1 = null;
    player2 = null;
    ball = null;
}

fn onDestroy() void {
    destroyPlayersAndBall();
    map = null;
    l_score = null;
    r_score = null;
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
        try onUpdate();
        rl.EndDrawing();
    }
}
