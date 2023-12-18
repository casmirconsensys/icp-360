import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Prim "mo:⛔";
import Prelude "mo:base/Prelude";

actor HttpCounter {

  type StreamingCallbackHttpResponse = {
    body : Blob;
    token : ?Token;
  };

  type Token = {
    // Add whatever fields you'd like
    artist_data : Text; //uuid https://customer.api.soundcharts.com/api/v2.9/artist/11e81bcc-9c1c-ce38-b96b-a0369fe50396
    arbitrary_data : Text;
    label_data : Text; //labelgrid https://api-sandbox.labelgrid.com/public
    track_data : Text; // GET /api/v2.20/song/{uuid}/playlist/current/{platform}
    album_chart : Text; //GET /api/v2/chart/album/by-platform/{platform}
    playlist_data : Text; // GET /api/v2.8/playlist/{uuid}86694fd0-cdce-11e8-8cff-549f35161576

  };

  type CallbackStrategy = {
    callback : shared query (Token) -> async StreamingCallbackHttpResponse;
    token : Token;
  };

  type StreamingStrategy = {
    #Callback : CallbackStrategy;
  };

  type HeaderField = (Text, Text);

  type HttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
    streaming_strategy : ?StreamingStrategy;
    upgrade : ?Bool;
  };

  type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };

  func isGzip(x : HeaderField) : Bool {
    Text.map(x.0, Prim.charToLower) == "accept-encoding" and Text.contains(Text.map(x.1, Prim.charToLower), #text "gzip");
  };

  stable var counter = 0;

  public query func http_request(req : HttpRequest) : async HttpResponse {
    switch (req.method, not Option.isNull(Array.find(req.headers, isGzip)), req.url) {
      case ("GET", false, "/stream") {
        {
          status_code = 200;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("Counter");
          streaming_strategy = ? #Callback({
            callback = http_streaming;
            token = {
              artist_data = "Artist_Data";
              arbitrary_data = "start";
              label_data = "Label_Data";
              track_data = "Track_Data";
              album_chart = "Album_Data";
              playlist_data = "Playlist_Data";

            };
          });
          upgrade = ?false;
        };
      };
      case ("GET", false, _) {
        {
          status_code = 200;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("Counter is " # Nat.toText(counter) # "\n" # req.url # "\n");
          streaming_strategy = null;
          upgrade = null;
        };
      };
      case ("GET", true, _) {
        {
          status_code = 200;
          headers = [("content-type", "text/plain"), ("content-encoding", "gzip")];
          body = "\1f\8b\08\00\98\02\1b\62\00\03\2b\2c\4d\2d\aa\e4\02\00\d6\80\2b\05\06\00\00\00";
          streaming_strategy = null;
          upgrade = null;
        };
      };

      case ("POST", _, _) {
        {
          status_code = 204;
          headers = [];
          body = "";
          streaming_strategy = null;
          upgrade = ?true;
        };
      };
      case _ {
        {
          status_code = 400;
          headers = [];
          body = "Invalid request";
          streaming_strategy = null;
          upgrade = null;
        };
      };
    };
  };

  public func http_request_update(req : HttpRequest) : async HttpResponse {
    switch (req.method, not Option.isNull(Array.find(req.headers, isGzip))) {
      case ("POST", false) {
        counter += 1;
        {
          status_code = 201;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("Counter updated to " # Nat.toText(counter) # "\n");
          streaming_strategy = null;
          upgrade = null;
        };
      };
      case ("POST", true) {
        counter += 1;
        {
          status_code = 201;
          headers = [("content-type", "text/plain"), ("content-encoding", "gzip")];
          body = "\1f\8b\08\00\37\02\1b\62\00\03\2b\2d\48\49\2c\49\e5\02\00\a8\da\91\6c\07\00\00\00";

          streaming_strategy = null;
          upgrade = null;
        };
      };
      case _ {
        {
          status_code = 400;
          headers = [];
          body = "Invalid request";
          streaming_strategy = null;
          upgrade = null;
        };
      };
    };
  };

  public query func http_streaming(token : Token) : async StreamingCallbackHttpResponse {
    switch (token.arbitrary_data) {
      case "start" {
        {
          body = Text.encodeUtf8(" is ");
          token = ?{
            album_chart = "next";
            arbitrary_data = "next";
            artist_data = "next";
            label_data = "next";
            playlist_data = "next";
            track_data = "next";
          };
        };
      };
      case "next" {
        {
          body = Text.encodeUtf8(Nat.toText(counter));
          token = ?{
            album_chart = "last";
            arbitrary_data = "last";
            artist_data = "last";
            label_data = "last";
            playlist_data = "last";
            track_data = "last";
          };
        };
      };
      case "last" {
        {
          body = Text.encodeUtf8(" streaming\n");
          token = null;
        };
      };
      case _ { Prelude.unreachable() };
    };
  };
};
