package;

import com.stencyl.Config;
import com.stencyl.Data;
import com.stencyl.Engine;
import com.stencyl.Input;
import com.stencyl.utils.motion.*;
import com.stencyl.utils.Utils;
#if stencyltools
import com.stencyl.utils.ToolsetInterface;
#end

import haxe.CallStack;
import haxe.Timer;

import lime.system.System;

import openfl.Lib;
import openfl.display.Application;
import openfl.display.Preloader;
import openfl.display.StageDisplayState;
import openfl.events.UncaughtErrorEvent;
import openfl.events.ErrorEvent;
import openfl.errors.Error;

import scripts.StencylPreloader;

using StringTools;

@:access(Universal)
@:access(lime.app.Application)
@:access(lime.system.System)
@:access(lime.utils.AssetLibrary)

@:dox(hide) class ApplicationMain
{
	public static var app:Application;
	private static var universal:Universal;
	
	public static function main ()
	{
		#if cppia
		if(StencylCppia.gamePath != null)
			Sys.setCwd(StencylCppia.gamePath);
		#end
		Universal.am = ApplicationMain;
		Universal.setupTracing(true);

		Config.load();
		Input.loadInputConfig();
		Universal.setupTracing();
		
		System.__registerEntryPoint ("::APP_FILE::", create);
		
		Lib.current;

		#if stencyltools
		new ToolsetInterface();
		#end

		#if html5
		//application is started from html script with System.embed, which calls create(config)
		#else
		create (null);
		#end

	}

	public static var reloadListeners = new Array<Void->Void>();

	public static function reloadGame()
	{
		for(reloadListener in reloadListeners)
		{
			reloadListener();
		}

		com.stencyl.behavior.Script.resetStatics();
		com.stencyl.graphics.G.resetStatics();
		com.stencyl.models.Actor.resetStatics();
		com.stencyl.models.Font.resetStatics();
		com.stencyl.models.GameModel.resetStatics();
		com.stencyl.models.Joystick.resetStatics();
		com.stencyl.models.SoundChannel.resetStatics();
		com.stencyl.models.actor.Animation.resetStatics();
		com.stencyl.models.actor.Collision.resetStatics();
		com.stencyl.models.actor.CollisionPoint.resetStatics();
		com.stencyl.models.collision.CollisionInfo.resetStatics();
		com.stencyl.models.scene.TileLayer.resetStatics();
		#if flash com.stencyl.utils.Kongregate.resetStatics(); #end
		com.stencyl.utils.motion.TweenManager.resetStatics();
		com.stencyl.utils.Utils.resetStatics();
		#if stencyltools com.stencyl.utils.ToolsetInterface.resetStatics(); #end
		com.stencyl.Data.resetStatics();
		com.stencyl.Input.resetStatics();
		com.stencyl.Engine.resetStatics();
		Lib.current.removeChild(universal);

		Input.loadInputConfig();
		universal = new Universal();
		Lib.current.addChild(universal);
		universal.preloaderComplete();
	}

	public static function create (config):Void
	{
		#if stencyltools
		{
			var startTime = Timer.stamp();
			var tryTimeout = function() {
				if(!ToolsetInterface.connected && Timer.stamp() - startTime > #if flash 5 #else 2 #end)
				{
					ToolsetInterface.cancelConnection();
				}
			};

			#if (flash || html5)

			if(!ToolsetInterface.ready)
			{
				var timer = new Timer(10);
				timer.run = function()
				{
					#if !flash
					ToolsetInterface.preloadedUpdate();
					#end

					tryTimeout();
					if(ToolsetInterface.ready)
					{
						timer.stop();
						create (config);
					}
				}

				return;
			}

			#else

			while(!ToolsetInterface.ready)
			{
				ToolsetInterface.preloadedUpdate();
				tryTimeout();
			}

			#end
		}
		#end

		app = new Application ();
		
		ManifestResources.init (config);
		
		app.meta["build"] = "::meta.buildNumber::";
		app.meta["company"] = "::meta.company::";
		app.meta["file"] = "::APP_FILE::";
		app.meta["name"] = "::meta.title::";
		app.meta["packageName"] = "::meta.packageName::";
		app.meta["version"] = "::meta.version::";
		
		::if (config.hxtelemetry != null)::#if hxtelemetry
		app.meta["hxtelemetry-allocations"] = "::config.hxtelemetry.allocations::";
		app.meta["hxtelemetry-host"] = "::config.hxtelemetry.host::";
		#end::end::
		
		#if !flash
		::foreach windows::
		var attributes:lime.ui.WindowAttributes = {
			
			allowHighDPI: ::allowHighDPI::,
			alwaysOnTop: ::alwaysOnTop::,
			borderless: ::borderless::,
			// display: ::display::,
			element: null,
			frameRate: ::fps::,
			#if !web fullscreen: ::fullscreen::, #end
			height: ::height::,
			hidden: ::hidden::,
			maximized: ::maximized::,
			minimized: ::minimized::,
			parameters: ::parameters::,
			resizable: ::resizable::,
			title: "::title::",
			width: ::width::,
			x: ::x::,
			y: ::y::,
			
		};
		
		attributes.context = {
			
			antialiasing: Config.antialias ? 2 : 0,
			background: ::background::,
			colorDepth: ::colorDepth::,
			depth: ::depthBuffer::,
			hardware: ::hardware::,
			stencil: ::stencilBuffer::,
			type: null,
			vsync: ::vsync::
			
		};
		
		if (app.window == null) {
			
			if (config != null) {
				
				for (field in Reflect.fields (config)) {
					
					if (Reflect.hasField (attributes, field)) {
						
						Reflect.setField (attributes, field, Reflect.field (config, field));
						
					} else if (Reflect.hasField (attributes.context, field)) {
						
						Reflect.setField (attributes.context, field, Reflect.field (config, field));
						
					}
					
				}
				
			}
			
		}
		
		app.createWindow (attributes);
		::end::
		#else
		
		app.window.context.attributes.background = ::WIN_BACKGROUND::;
		app.window.frameRate = ::WIN_FPS::;
		
		#end
		
		if(!Config.releaseMode)
		{
			Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtErrorHandler);
		}
		
		Universal.initWindow(app.window);
		universal = new Universal();
		Lib.current.addChild(universal);
		var imgBase = Engine.IMG_BASE;
		
		#if sys
		var preloadPaths = Utils.getConfigText("config/preloadPaths.txt");
		for(library in ManifestResources.preloadLibraries)
		{
			for(path in preloadPaths.split("\n"))
			{
				if(path.length == 0)
					continue;
				path = path.replace("IMG_BASE", imgBase);
				library.preload.set(path, true);
			}
		}
		#end
		
		#if actuate
		motion.actuators.SimpleActuator.getTime = function():Float {
			return Engine.totalElapsedTime / 1000;
		}
		#end

		var preloader = new StencylPreloader();
		preloader.onComplete.add(universal.preloaderComplete);
		app.preloader.onProgress.add(preloader.onUpdate);
		app.preloader.onComplete.add(preloader.onLoaded);
		
		// for Poki
		app.preloader.onComplete.add(onLoaded);
		
		for (library in ManifestResources.preloadLibraries)
		{
			app.preloader.addLibrary (library);
		}
		for (name in ManifestResources.preloadLibraryNames)
		{
			app.preloader.addLibraryName (name);
		}
		
		untyped __js__
		('
			PokiSDK.init().then(
				() => {
		');
		
		trace("PokiSDK initialized");
		startLoad();
		
		untyped __js__
		('
			}   
			).catch(
				() => {
		');
		
		trace("Adblock enabled");
		StencylPoki.adBlock = true;
		startLoad();
		
		untyped __js__('});');
		
		StencylPoki.pokiSDK = untyped __js__ ("PokiSDK");
		
		var result = app.exec ();

		#if (sys && !ios)
		System.exit (result);
		#end
	}
	
	public static function startLoad()
	{
		#if (!pokiDebug && !skipPoki)
		untyped __js__
		('
		// INSERT POKI SITELOCK CODE HERE
		
		');
		#end
	
		app.preloader.load ();
	}
	
	public static function onUpdate(loaded:Int, total:Int)
	{
		var percentLoaded = loaded / total;
	}
	
	public static function onLoaded()
	{
		untyped __js__('PokiSDK.gameLoadingFinished();');
	}

	static function uncaughtErrorHandler(event:UncaughtErrorEvent):Void
	{
		#if (html5 && stencyltools)
		
		if(Config.useGciLogging && Reflect.hasField(event.error, "stack"))
		{
			trace(event.error.stack);
		}
		
		#else
		
		if (Std.is(event.error, Error))
		{
			trace(cast(event.error, Error).getStackTrace());
		}
		else if (Std.is(event.error, ErrorEvent))
		{
			trace(cast(event.error, ErrorEvent).text);
		}
		else
		{
			trace(event.error.toString());
		}
		
		#end
		
		#if (debug && stencyltools && cpp)
		
		trace(CallStack.toString(CallStack.exceptionStack()));
		ToolsetInterface.preloadedUpdate();
		
		#end
	}
}