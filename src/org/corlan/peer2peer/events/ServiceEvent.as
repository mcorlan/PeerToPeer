package org.corlan.peer2peer.events { 
	import flash.events.Event;
	
	public class ServiceEvent extends Event {
		
		public static const RESULT:String = "result";
		public static const CONNECTED:String = "connected";
		public static const DISCONNECTED:String = "disconnected";
		public static const PEER_CONNECT:String = "peerconnect";
		public static const PEER_DISCONNECT:String = "peerdisconnect";
		
		public static const GET_IP:String = "getip";
		public static const GET_COMP_NAME:String = "getname";
		public static const COMP_NAME:String = "name";
		
		public var peerID:String;
		public var from:String;
		public var to:String;
		public var what:String;
		public var body:Object;
		
		public function ServiceEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);
		}
	}
}