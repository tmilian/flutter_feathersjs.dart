/// Socketio Connected
class Connected {}

/// Socketio Disconnected
class DisConnected {}

/// Feathers Js realtime event data
class FeathersJsEventData<T> {
  FeathersJsEventType? type;
  T? data;
  FeathersJsEventData({this.type, this.data});
}

/// Feathers Js realtime event type
enum FeathersJsEventType { updated, patched, created, removed }
