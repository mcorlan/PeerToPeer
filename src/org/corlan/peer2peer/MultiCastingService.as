package org.corlan.peer2peer {
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.net.GroupSpecifier;
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	import flash.net.NetStream;
	import flash.net.NetworkInfo;
	import flash.net.NetworkInterface;
	import org.corlan.peer2peer.events.ServiceEvent;
	
	
	[Event(name="connected", type="org.corlan.events.ServiceEvent")]
	[Event(name="disconnected", type="org.corlan.events.ServiceEvent")]
	[Event(name="peerconnect", type="org.corlan.events.ServiceEvent")]
	[Event(name="peerdisconnect", type="org.corlan.events.ServiceEvent")]
	[Event(name="result", type="org.corlan.events.ServiceEvent")]
	
	public class MultiCastingService extends EventDispatcher {
		
		private var netConnection:NetConnection = null;
		private var netStream:NetStream = null;
		private var netGroup:NetGroup = null;
		private var groupSpecifier:GroupSpecifier;
		private var sequenceNumber:uint = 0;
		private var groupName:String = "org.corlan/";
		private var IPMulticastAddress:String = "224.0.0.1:4000";
		public var userName:String;
		
		private var published:Boolean = false;
		private var connected:Boolean = false;
		private var joinedGroup:Boolean = false;
		private var logging:Boolean;
		
		private static const SERVER:String = "rtmfp:";
//		private static const SERVER:String = "rtmfp://stratus.adobe.com/...";
		
		public function MultiCastingService(user:String=null, logEnabled:Boolean = false, 
											gn:String="loveisintheair", ip:String="224.0.0.1:4000", target:IEventDispatcher=null) {
			super(target);
			if (user)
				userName = user;
			else
				userName = "user-" + int(Math.random() * 65536);
			logging = logEnabled;
			groupName += gn;
			IPMulticastAddress = ip;
		}
		
		public function connect():void {
			log("Connecting to \"" + SERVER + "\" ...\n");
			netConnection = new NetConnection();
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			netConnection.connect(SERVER);
		}
		
		public function get isReady():Boolean {
			return connected && published && joinedGroup;
		}
		
		public function get neighborCount():int {
			if (netGroup)
				return netGroup.neighborCount;
			else
				return 0;
		}
		
		private function netStatusHandler(e:NetStatusEvent):void {
			log(e.currentTarget + " " +  e.info.code + "\n");
			if (netGroup)
				log("netGroup.neighborCount " + netGroup.neighborCount);
			switch(e.info.code) {
				case "NetConnection.Connect.Success":
					onConnect();
					break;
				case "NetConnection.Connect.Closed":
				case "NetConnection.Connect.Failed":
				case "NetConnection.Connect.Rejected":
				case "NetConnection.Connect.AppShutdown":
				case "NetConnection.Connect.InvalidApp":    
					disconnect();
					break;
				
				case "NetStream.Connect.Success": // e.info.stream
					onNetStreamConnect();
					break;
				
				case "NetStream.Connect.Rejected": // e.info.stream
				case "NetStream.Connect.Failed": // e.info.stream
					disconnect();
					break;
				
				case "NetGroup.Connect.Success": // e.info.group
					onNetGroupConnect();
					break;
				
				case "NetGroup.Connect.Rejected": // e.info.group
				case "NetGroup.Connect.Failed": // e.info.group
					disconnect();
					break;
				
				case "NetGroup.Posting.Notify": // e.info.message, e.info.messageID
				case "NetGroup.SendTo.Notify":	
					onMessage(e.info.message);
					break;

				case "NetGroup.Neighbor.Connect": //peer connected
					onPeerConnect(e.info.peerID);
					break;
				case "NetGroup.Neighbor.Disconnect": //peer disconnected
					onPeerDisconnect(e.info.peerID);
					break;
				
				default:
					break;
			}
		}
		
		private function onPeerDisconnect(peerID:String):void {
			var e:ServiceEvent = new ServiceEvent(ServiceEvent.PEER_DISCONNECT);
			e.peerID = peerID;
			dispatchEvent(e);
		}
		
		private function onPeerConnect(peerID:String):void {
			var e:ServiceEvent = new ServiceEvent(ServiceEvent.PEER_CONNECT);
			e.peerID = peerID;
			dispatchEvent(e);
		}
		
		private function onConnect():void {
			published = false;
			log("Connected\n");
			connected = true;
			
			groupSpecifier = new GroupSpecifier(groupName);
			groupSpecifier.addIPMulticastAddress(IPMulticastAddress);
			groupSpecifier.ipMulticastMemberUpdatesEnabled = true;
			groupSpecifier.multicastEnabled = true;
			groupSpecifier.postingEnabled = true;
			groupSpecifier.peerToPeerDisabled = false;
			groupSpecifier.objectReplicationEnabled = true;
			groupSpecifier.routingEnabled = true;
			groupSpecifier.serverChannelEnabled = true;
			
			netStream = new NetStream(netConnection, groupSpecifier.groupspecWithAuthorizations());
			netStream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			
			netGroup = new NetGroup(netConnection, groupSpecifier.groupspecWithAuthorizations());
			netGroup.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			
			log("Join \"" + groupSpecifier.groupspecWithAuthorizations() + "\"\n");
		}
		
		private function onNetStreamConnect():void {
			log("onNetStreamConnect: NetStream.Connect.Success");
			if (!published) {
				published = true;
				netStream.client = this;
			}
		}
		
		private function onNetGroupConnect():void {
			log("onNetGroupConnect: NetGroup.Connect.Success");
			joinedGroup = true;
			var e:Event = new ServiceEvent(ServiceEvent.CONNECTED);
			dispatchEvent(e);
			//ping for other group members
		}
		
		public function disconnect():void {
			if(netConnection)
				netConnection.close();
		}
		
		private function onDisconnect():void {
			log("Disconnected\n");
			netConnection = null;
			netStream = null;
			netGroup = null;
			connected = false;
			published = false;
			joinedGroup = false;
			var e:Event = new ServiceEvent(ServiceEvent.DISCONNECTED);
			dispatchEvent(e);
		}
		
		public function post(mess:Object, what:String, to:String=null, sendToAllNeighbors:Boolean=false):void {
			var message:Object = new Object();
			message.sender = netConnection.nearID;
			message.sequence = sequenceNumber++;
			message.from = userName;
			message.to = to;
			message.what = what;
			message.body = mess;
			
			if (!sendToAllNeighbors)
				netGroup.post(message);
			else
				netGroup.sendToAllNeighbors(message);
			log("SEND <" + userName + " | " + to + "> " + what +"\n");
		}
		
		private function onMessage(message:Object):void {
			var e:ServiceEvent = new ServiceEvent(ServiceEvent.RESULT);
			e.peerID = message.sender;
			e.from = message.from;
			e.to = message.to;
			e.what = message.what;
			e.body = message.body;
			dispatchEvent(e);
			log("RECEIVED <" + message.from + "> ==> " + message.what + "\n");
		}
		
		private function log(msg:Object):void	{
			if (logging) 
				trace(msg);
		}
	}
}