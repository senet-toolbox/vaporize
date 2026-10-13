const std = @import("std");
const Vapor = @import("../Vapor.zig");
const Kit = Vapor.Kit;

const Provider = enum {
    google,
    github,
    apple,
    azure,
};

const Options = struct {
    client_id: []const u8 = "",
    redirect_uri: []const u8 = "",
    response_type: []const u8 = "",
    scope: []const u8 = "",

    // google specific
    access_type: []const u8 = "",
    prompt: []const u8 = "",

    // apple specific
    response_mode: []const u8 = "",
    state: []const u8 = "",
    nonce: []const u8 = "",
};

pub const Config = struct {
    client_id: []const u8,
};

pub const Clients = struct {
    google: ?Config = null,
    github: ?Config = null,
    azure: ?Config = null,
    apple: ?Config = null,
};

const KeyStone = @This();
var options: Options = Options{};
pub var keystone: KeyStone = undefined;
clients: Clients = undefined,
provider: Provider = undefined,

pub fn init(clients: Clients) void {
    // _ = Vapor.createHook({}, hooks, "/nightwatch/auth");
    keystone = KeyStone{
        .clients = clients,
    };
}

fn hooks(_: void) void {
    const params_str = Vapor.Kit.getWindowParams() orelse return;
    if (params_str.len == 0) return;
    const params = Kit.parseParams(params_str, &Vapor.allocator_global) catch return orelse return;
    const code = params.get("code") orelse return;
    const cookie = Vapor.getCookie("oauth_provider") orelse return;
    const provider = std.meta.stringToEnum(Provider, cookie) orelse return;
    switch (provider) {
        .google => exchangeGoogle(),
        .github => exchangeGithub(code),
        .apple => exchangeApple(),
        .azure => exchangeAzure(),
    }
}

pub fn handleAuthExchanges(_: void) void {
    const params_str = Vapor.Kit.getWindowParams() orelse return;
    if (params_str.len == 0) return;
    const params = Kit.parseParams(params_str, &Vapor.allocator_global) catch return orelse return;
    const code = params.get("code") orelse return;
    const cookie = Vapor.getCookie("oauth_provider") orelse return;
    const provider = std.meta.stringToEnum(Provider, cookie) orelse return;
    switch (provider) {
        .google => exchangeGoogle(),
        .github => exchangeGithub(code),
        .apple => exchangeApple(),
        .azure => exchangeAzure(),
    }
}

fn exchangeGithub(code: []const u8) void {
    const params_str = Kit.getWindowParams() orelse return;
    if (params_str.len == 0) return;
    const body = Vapor.fmtln("auth-code={s}", .{code});
    Kit.fetchWithParams("http://localhost:8443/exchange/github/token", {}, logToken, .{
        .method = "POST",
        .body = body,
        .credentials = "include",
        .headers = .{
            .content_type = "application/x-www-form-urlencoded",
        },
    });
}

fn exchangeGoogle() void {
    const params_str = Kit.getWindowParams() orelse return;
    if (params_str.len == 0) return;
    const params = Kit.parseParams(params_str, &Vapor.allocator_global) catch return orelse return;
    const code = params.get("code") orelse return;
    const body = Vapor.fmtln("auth-code={s}", .{code});
    Kit.fetchWithParams("http://localhost:8443/exchange/google/token", {}, logToken, .{
        .method = "POST",
        .body = body,
        .credentials = "include",
        .headers = .{
            .content_type = "application/x-www-form-urlencoded",
        },
        .body_type = .string,
    });
}

fn exchangeApple() void {
    const params_str = Kit.getWindowParams() orelse return;
    if (params_str.len == 0) return;
    Vapor.printlnSrc("Params {s}", .{params_str}, @src());
    const params = Kit.parseParams(params_str, &Vapor.allocator_global) catch return orelse return;
    Vapor.printlnSrc("{s}", .{params.get("code") orelse ""}, @src());
    const code = params.get("code") orelse return;
    const body = Vapor.fmtln("auth-code={s}", .{code});
    Kit.fetchWithParams("http://localhost:8443/exchange/google/token", {}, logToken, .{
        .method = "POST",
        .body = body,
        .credentials = "include",
        .headers = .{
            .content_type = "application/x-www-form-urlencoded",
        },
    });
}

fn exchangeAzure() void {
    const params_str = Kit.getWindowParams() orelse return;
    if (params_str.len == 0) return;
    Vapor.printlnSrc("Params {s}", .{params_str}, @src());
    const params = Kit.parseParams(params_str, &Vapor.allocator_global) catch return orelse return;
    Vapor.printlnSrc("{s}", .{params.get("code") orelse ""}, @src());
    const code = params.get("code") orelse return;
    const body = Vapor.fmtln("auth-code={s}", .{code});
    Kit.fetchWithParams("http://localhost:8443/exchange/google/token", {}, logToken, .{
        .method = "POST",
        .body = body,
        .credentials = "include",
        .headers = .{
            .content_type = "application/x-www-form-urlencoded",
        },
    });
}

fn logToken(_: void, resp: Kit.Response) void {
    Vapor.printlnSrc("Logged response {any}", .{resp.code}, @src());
    const path = Kit.getWindowPath();
    if (resp.code == 401 and !std.mem.eql(u8, "/nightwatch/auth", path)) {
        Kit.routePush("/nightwatch/auth");
    } else if (resp.code == 200 and std.mem.eql(u8, "/nightwatch/auth", path)) {
        Kit.routePush("/nightwatch/routes");
    } else if (resp.code == 500 and !std.mem.eql(u8, "/nightwatch/auth", path)) {
        Kit.routePush("/nightwatch/auth");
    }
    // Kit.navigate("/nightwatch/routes");
}

pub fn getSession() ?[]const u8 {
    return Vapor.getCookie("_nightwatch-session");
}

pub fn validate() void {
    Kit.fetchWithParams("http://localhost:8443/validate/google/token", {}, logToken, .{
        .method = "POST",
        .body = "",
        .credentials = "include",
        .headers = .{
            .content_type = "application/x-www-form-urlencoded",
        },
    });
}

pub fn signInWithOauth(provider: Provider) void {
    switch (provider) {
        .google => {
            const googleClient = keystone.clients.google orelse return;
            options.client_id = googleClient.client_id;
            options.redirect_uri = "http://localhost:5173/nightwatch/auth";
            options.response_type = "code";
            options.scope = "openid email profile";
            options.access_type = "offline";
            options.prompt = "consent";
            const cookie = "oauth_provider=google; path=/; secure; samesite=strict";
            Vapor.setCookie(cookie);
            keystone.google() catch return;
        },
        .apple => {
            const appleClient = keystone.clients.apple orelse return;
            options.response_type = "code id_token";
            options.client_id = appleClient.client_id;
            options.redirect_uri = "http://localhost:5173/nightwatch/auth";
            options.scope = "name email";
            options.response_mode = "form_post";
            options.state = "random_csrf_token";
            options.nonce = "random_nonce_value";
            const cookie = "oauth_provider=apple; path=/; secure; samesite=strict";
            Vapor.setCookie(cookie);
            keystone.apple() catch return;
        },
        .github => {
            const githubClient = keystone.clients.github orelse return;
            options.client_id = githubClient.client_id;
            options.redirect_uri = "http://localhost:5173/nightwatch/auth";
            options.scope = "read:user user:email";
            options.state = "random_csrf_token";
            const cookie = "oauth_provider=github; path=/; secure; samesite=strict";
            Vapor.setCookie(cookie);
            keystone.github() catch return;
        },
        else => {},
    }
}

fn apple(_: KeyStone) !void {
    var query: Kit.QueryBuilder = undefined;
    try query.init(Vapor.allocator_global);

    try query.add("response_type", "code id_token"); // or your actual callback URL
    try query.add("client_id", options.client_id);
    try query.add("redirect_uri", options.redirect_uri); // or your actual callback URL
    try query.add("scope", options.scope); // or your actual callback URL
    try query.add("response_mode", options.response_mode); // or your actual callback URL
    try query.add("state", options.state); // or your actual callback URL
    try query.add("nonce", options.nonce); // or your actual callback URL
    //
    try query.queryStrEncode();
    const full_url = try query.generateUrl("https://appleid.apple.com/auth/authorize", query.str);
    defer Vapor.allocator_global.free(full_url);
    Vapor.println("{s}\n", .{full_url});

    // Vapor.printlnSrc("{s}\n", .{full_url}, @src());
    Kit.setWindowLocation(full_url);
}

fn github(_: KeyStone) !void {
    var query: Kit.QueryBuilder = undefined;
    try query.init(Vapor.allocator_global);

    try query.add("client_id", options.client_id);
    try query.add("redirect_uri", options.redirect_uri); // or your actual callback URL
    try query.add("scope", options.scope); // or your actual callback URL
    try query.add("state", options.state); // or your actual callback URL
    //
    try query.queryStrEncode();
    const full_url = try query.generateUrl("https://github.com/login/oauth/authorize", query.str);
    defer Vapor.allocator_global.free(full_url);

    Vapor.printlnSrc("{s}\n", .{full_url}, @src());
    Kit.setWindowLocation(full_url);
}

fn google(_: KeyStone) !void {
    var query: Kit.QueryBuilder = undefined;
    try query.init(Vapor.allocator_global);

    try query.add("client_id", options.client_id);
    try query.add("redirect_uri", options.redirect_uri); // or your actual callback URL
    try query.add("response_type", options.response_type); // or your actual callback URL
    try query.add("scope", options.scope); // or your actual callback URL
    try query.add("access_type", options.access_type); // or your actual callback URL
    try query.add("prompt", options.prompt); // or your actual callback URL
    //
    try query.queryStrEncode();
    const full_url = try query.generateUrl("https://accounts.google.com/o/oauth2/v2/auth", query.str);
    defer Vapor.allocator_global.free(full_url);

    Vapor.printlnSrc("{s}\n", .{full_url}, @src());
    Kit.setWindowLocation(full_url);
}
