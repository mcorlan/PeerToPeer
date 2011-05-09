package org.corlan.peer2peer {
	
	import flash.filesystem.File;
	import flash.net.NetworkInfo;
	import flash.net.NetworkInterface;
	
	public class Utils 	{
		
		public static function getIPs():String {
			var interfaces:Vector.<NetworkInterface> = new Vector.<NetworkInterface>();
			interfaces =  NetworkInfo.networkInfo.findInterfaces()
			var ips:Array = new Array();
			for each (var netf:NetworkInterface in interfaces) {
				if (!netf.active)
					continue;
				ips.push(netf.addresses[0].address);	
			}
			if (ips.length)
				return ips.join("|");
			else
				return "";
		}
		
		public static function getComputerName():String {
			return File.userDirectory.name;
		}
	}
}