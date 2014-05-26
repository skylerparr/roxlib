package com.roxstudio.haxe.net;

import flash.events.ErrorEvent;
import org.bytearray.gif.decoder.GIFDecoder;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Loader;
import flash.errors.Error;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.utils.ByteArray;

/**
* Currently support: String, ByteArray, BitmapData
**/
class RoxURLLoader {

    public static inline var BINARY = 1;
    public static inline var TEXT = 2;
    public static inline var IMAGE = 3;

    public var url(default, null): String;
    public var type(default, null): Int;
    public var started(default, null): Bool = false;

    public function new(url: String, type: Int = BINARY, onComplete: Bool -> Dynamic -> Void) {
        this.url = url;
        this.type = type;
        this.onComplete = onComplete;
    }

    public dynamic function onComplete(isOk: Bool, data: Dynamic) : Void {}

    public dynamic function onRaw(rawData: ByteArray) : Void {}

    public dynamic function onProgress(bytesLoaded: Float, bytesTotal: Float) : Void {}

    public function start() {
        if (started) return;
        started = true;
        try {
            var loader = new URLLoader();
            loader.dataFormat = URLLoaderDataFormat.BINARY;
            loader.addEventListener(Event.COMPLETE, onDone);
            if (onProgress != null) {
                loader.addEventListener(ProgressEvent.PROGRESS, function(e: ProgressEvent) {
                    onProgress(e.bytesLoaded, e.bytesTotal);
                });
            }
            loader.addEventListener(IOErrorEvent.IO_ERROR, function(e: Event) {
                onComplete(false, new Error(IOErrorEvent.IO_ERROR));
            });
#if !html5
            loader.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function(e: Event) {
                onComplete(false, new Error(flash.events.SecurityErrorEvent.SECURITY_ERROR));
            });
#end
            loader.load(new URLRequest(url));
        } catch (e: Dynamic) {
            haxe.Timer.delay(function() { onComplete(false, e); }, 0);
        }
    }

    private function onDone(e: Dynamic) {
        var ba: ByteArray = cast e.target.data;
        if (onRaw != null) onRaw(ba);
        switch (type) {
            case IMAGE:
                var iscpp = #if cpp true #else false #end;
                if (iscpp && ba[0] == 'G'.code && ba[1] == 'I'.code && ba[2] == 'F'.code) {
                    var gifdec = new GIFDecoder();
                    gifdec.read(ba);
                    var bmd = gifdec.getFrameCount() > 0 ? gifdec.getImage().bitmapData : new BitmapData(0, 0);
                    onComplete(true, bmd);
                } else { // not a gif image or it's on flash target
                    var ldr = new Loader();
                    var imageDone = function(_) {
                        var bmd = cast(ldr.content, Bitmap).bitmapData;
                        onComplete(true, bmd);
                    }
                    ldr.loadBytes(ba);
                    if (ldr.content != null) {
                        imageDone(null);
                    } else {
                        var ldri = ldr.contentLoaderInfo;
                        ldri.addEventListener(Event.COMPLETE, imageDone);
                    }
                }
            case TEXT:
                onComplete(true, ba.toString());
            case BINARY:
                onComplete(true, ba);
        }
    }

}
