package flash.media;


import flash.errors.Error;
import flash.events.EventDispatcher;
import flash.events.IEventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.SampleDataEvent;
import flash.net.URLRequest;
import flash.utils.ByteArray;
import flash.utils.Endian;
import flash.Lib;


@:autoBuild(openfl.Assets.embedSound())
class Sound extends EventDispatcher {
	
	
	public var bytesLoaded (default, null):Int;
	public var bytesTotal (default, null):Int;
	public var id3 (get, null):ID3Info;
	public var isBuffering (get, null):Bool;
	public var length (get, null):Float;
	public var url (default, null):String;
	
	@:noCompletion private var __handle:Dynamic;
	@:noCompletion private var __loading:Bool;
	@:noCompletion private var __dynamicSound:Bool;
	
	
	public function new (stream:URLRequest = null, context:SoundLoaderContext = null, forcePlayAsMusic:Bool = false) {
		
		super ();
		
		bytesLoaded = 0;
		bytesTotal = 0;
		__loading = false;
		__dynamicSound = false;
		
		if (stream != null) {
			
			load (stream, context, forcePlayAsMusic);
			
		}
		
	}
	
	
	override public function addEventListener (type:String, listener:Function, useCapture:Bool = false, priority:Int = 0, useWeakReference:Bool = false):Void {
		
		super.addEventListener (type, listener, useCapture, priority, useWeakReference);
		
		if (type == SampleDataEvent.SAMPLE_DATA) {
			
			if (__handle != null) {
				
				throw "Can't use dynamic sound once file loaded";
				
			}
			
			__dynamicSound = true;
			__loading = false;
			
		}
		
	}
	
	
	public function close ():Void {
		
		if (__handle != null) {
			
			nme_sound_close (__handle);
			
		}
		
		__handle = 0;
		__loading = false;
		
	}
	
	
	public function load (stream:URLRequest, context:SoundLoaderContext = null, forcePlayAsMusic:Bool = false):Void {
		
		bytesLoaded = 0;
		bytesTotal = 0;
		
		__handle = nme_sound_from_file (stream.url, forcePlayAsMusic);
		
		if (__handle == null) {
			
			throw("Could not load:" + stream.url);
			
		} else {
			
			url = stream.url;
			__loading = false;
			__checkLoading ();
			
		}
		
		
	}
	
	
	public function loadCompressedDataFromByteArray (bytes:ByteArray, length:Int, forcePlayAsMusic:Bool = false):Void {
		
		bytesLoaded = length;
		bytesTotal = length;
		
		__handle = nme_sound_from_data (bytes, length, forcePlayAsMusic);
		
		if (__handle == null) {
			
			throw ("Could not load buffer with length: " + length);
			
		}
		
	}
	
	
	public function loadPCMFromByteArray (bytes:ByteArray, samples:Int, format:String = "float", stereo:Bool = true, sampleRate:Float = 44100.0):Void {
		
		var wav = new ByteArray ();
		wav.endian = Endian.LITTLE_ENDIAN;
		
		var audioFormat:Int = switch (format) {
			
			case "float": 3;
			case "short": 1;
			default: throw (new Error ('Unsupported format $format'));
			
		}
		
		var numChannels = stereo ? 2 : 1;
		var sampleRate = Std.int (sampleRate);
		var bitsPerSample = switch(format) {
			
			case "float": 32;
			case "short": 16;
			default: throw (new Error ('Unsupported format $format'));
			
		};
		
		var byteRate:Int = Std.int (sampleRate * numChannels * bitsPerSample / 8);
		var blockAlign:Int = Std.int(numChannels * bitsPerSample / 8);
		var numSamples:Int = Std.int(bytes.length / blockAlign);
		
		wav.writeUTFBytes ("RIFF");
		wav.writeInt (36 + bytes.length);
		wav.writeUTFBytes ("WAVE");
		wav.writeUTFBytes ("fmt ");
		wav.writeInt (16);
		wav.writeShort ((audioFormat));
		wav.writeShort ((numChannels));
		wav.writeInt ((sampleRate));
		wav.writeInt ((byteRate));
		wav.writeShort ((blockAlign));
		wav.writeShort ((bitsPerSample));
		wav.writeUTFBytes ("data");
		wav.writeInt ((bytes.length));
		wav.writeBytes (bytes, 0, bytes.length);
		
		wav.position = 0;
		loadCompressedDataFromByteArray (wav, wav.length);
		
	}
	
	
	public function play (startTime:Float = 0, loops:Int = 0, soundTransform:SoundTransform = null):SoundChannel {
		
		__checkLoading ();
		
		if (__dynamicSound) {
			
			var request = new SampleDataEvent (SampleDataEvent.SAMPLE_DATA);
			dispatchEvent (request);
			
			if (request.data.length > 0) {
				
				__handle = nme_sound_channel_create_dynamic (request.data, soundTransform);
				
			}
			
			if (__handle == null) {
				
				return null;
				
			}
			
			var result = SoundChannel.createDynamic (__handle, soundTransform, this);
			__handle = null;
			return result;
			
		} else {
			
			if (__handle == null || __loading) {
				
				return null;
				
			}
			
			return new SoundChannel (__handle, startTime, loops, soundTransform);
			
		}
		
	}
	
	
	@:noCompletion private function __checkLoading ():Void {
		
		if (!__dynamicSound && __loading && __handle != null) {
			
			var status:Dynamic = nme_sound_get_status (__handle);
			
			if (status == null) {
				
				throw "Could not get sound status";
				
			}
			
			bytesLoaded = status.bytesLoaded;
			bytesTotal = status.bytesTotal;
			__loading = bytesLoaded < bytesTotal;
			
			if (status.error != null) {
				
				throw (status.error);
				
			}
			
		}
		
	}
	
	
	@:noCompletion private function __onError (msg:String):Void {
		
		dispatchEvent (new IOErrorEvent (IOErrorEvent.IO_ERROR, true, false, msg));
		__handle = null;
		__loading = true;
		
	}
	
	
	
	
	// Getters & Setters
	
	
	
	
	private function get_id3 ():ID3Info {
		
		__checkLoading ();
		
		if (__handle == null || __loading) {
			
			return null;
			
		}
		
		var id3 = new ID3Info ();
		nme_sound_get_id3 (__handle, id3);
		return id3;
		
	}
	
	
	private function get_isBuffering ():Bool {
		
		__checkLoading ();
		return (__loading && __handle == null);
		
	}
	
	
	private function get_length ():Float {
		
		if (__handle == null || __loading) {
			
			return 0;
			
		}
		
		return nme_sound_get_length (__handle);
		
	}
	
	
	
	
	// Native Methods
	
	
	
	
	private static var nme_sound_from_file = Lib.load ("nme", "nme_sound_from_file", 2);
	private static var nme_sound_from_data = Lib.load ("nme", "nme_sound_from_data", 3);
	private static var nme_sound_get_id3 = Lib.load ("nme", "nme_sound_get_id3", 2);
	private static var nme_sound_get_length = Lib.load ("nme", "nme_sound_get_length", 1);
	private static var nme_sound_close = Lib.load ("nme", "nme_sound_close", 1);
	private static var nme_sound_get_status = Lib.load ("nme", "nme_sound_get_status", 1);
	private static var nme_sound_channel_create_dynamic = Lib.load ("nme", "nme_sound_channel_create_dynamic", 2);
	
	
}