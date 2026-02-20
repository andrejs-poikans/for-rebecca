
//for Rebecca Lane
//11-02-2026

//a step sequencer for microtonal samples and synthesis
//made to be performed with a foot pedal

//v1.9
//works with supercollider 3.13.0 on MacOS Tahoe 26.0.1 (Apple Silicon)

//adaptation from 'compos-mentis' software for Jon Heilbron and Rebecca Lane 2025
//by Andrejs Poikāns

(

Server.local.options.sampleRate = 48000;
Server.internal.options.sampleRate = 48000;
~path = (PathName(thisProcess.nowExecutingPath)).pathOnly;
~currentPath = ~path ++ "presets/rebecca";

s.waitForBoot({

	~func = {
		//////////////////////////////////////////////////////////////////////////
		// load samples

		Buffer.freeAll(s);

		~buf = SoundFile.collectIntoBuffers(~path ++ "samples/*", s);
		~silent = Buffer.alloc(s, s.sampleRate * 8.0, 2);
		~limitBus = Bus.audio(s, numChannels: 2);

		"samples and busses loaded".postln;

		(1/10).wait;
		//////////////////////////////////////////////////////////////////////////
		// load synths

		SynthDef(\playback, {
			|bufnum = 1, gate = 1, amp = 1, gain = 1, pan = 0.0, loop = 0, trig = 0, at = 0.5, rel = 0.5, dur = 16, startPos = 0.0|
			var sig, env;
			sig = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), trig, startPos: (BufDur.kr(bufnum)*startPos), loop:loop, doneAction:2);
			env = EnvGen.ar(Env([0, amp, 0], [at, rel]*dur, \wel), gate, doneAction:2);
			sig = sig*env;
			sig = sig*gain*gate;
			sig = Balance2.ar(sig[0], sig[1], pan);
			Out.ar(~limitBus, sig);
		}).add;


		SynthDef(\fsine, {
			|amp = 1, gain = 0.2,  gate = 1, freq = 160, pan = 0.0, at = 0.5, rel = 0.5, dur = 16, leg = 1|
			var sig, env;
			sig = FSinOsc.ar(freq, mul:0.1);
			env = EnvGen.ar(Env([0, amp, 0], [at, rel*leg]*dur, \wel), doneAction:2);
			sig = sig*env;
			sig = sig*gain*freq.expexp(20, 20000, 1, 0.1)*gate;
			sig = Pan2.ar(sig, pan);
			Out.ar(~limitBus, sig);
		}).add;


		SynthDef(\fsaw, {
			|gain = 0.2, amp = 1, gate = 1, freq = 160, pan = 0.0, at = 0.5, rel = 0.5, dur = 16|
			var sig, env;
			sig = LFSaw.ar(freq, iphase: [1, 1.5]);
			sig = RLPF.ar(sig, freq * SinOsc.ar(1 / [56, 45], 0, 3/4, 4/3), 0.99);
			env = EnvGen.ar(Env([0, amp, 0], [at, rel]*dur, \wel), doneAction:2);
			sig = sig*env;
			sig = sig*gain*gate;
			sig = Splay.ar(sig, 0.25, 0.1, pan);
			Out.ar(~limitBus, sig);
		}).add;


		SynthDef(\klank, {
			|gain = 0.5, amp = 1, gate = 1, freq = 160, pan = 0.0, at = 0.5, rel = 0.5, dur = 16|
			var sig, env, harmonics = 12;
			env = EnvGen.ar(Env([0, amp, 0], [at, rel]*dur, \wel), doneAction:2);
			sig = Klank.ar(`[
				Array.series(12, 1, 1) * freq,          // frequencies
				nil,                                // filter amplitudes
				Array.geom(harmonics, 1, 8/12)],             // decay times for ring filters
			PinkNoise.ar([0.007, 0.007]*gain*env));
			sig = LPF.ar(sig, freq*4);
			sig = sig*env;
			sig = sig*gain*gate;
			sig = Splay.ar(sig, 0.25, 1, pan);
			Out.ar(~limitBus, sig);
		}).add;

		SynthDef(\limit, {
			var sig, in;
			in = InBus.ar(~limitBus, 2);
			sig = Limiter.ar(in);
			Out.ar(0, sig);
		}).add;

		"synths loaded".postln;

		(1/10).wait;

		//////////////////////////////////////////////////////////////////////////
		// load tones
		~reader = Object.readArchive(~currentPath);
		~cueSpace = ~reader[0];
		~sampleList = ~reader[1];
		~currentCueArray = ~reader[2];
		~cueNum = ~reader[3];
		~amp = ~reader[4];
		~pan = ~reader[5];
		~forwardBtn = ~reader[6];
		~backwardBtn = ~reader[7];

		~samplerOn = ~reader[8];
		~sineOn = ~reader[9];
		~sawOn = ~reader[10];
		~klankOn = ~reader[11];
		~particlesOn = ~reader[12];
		~cueOn = ~reader[13];

		~particleList = ~reader[14];
		~particleSpace = ~reader[15];
		~mixSpace = ~reader[16];



		//make a sample list for the selection
		~sampleList = Array.fill(~buf.size, {|i| ~buf[i].path.basename.splitext[0].asString});


		"parameters, list of samples loaded".postln;

		(1/10).wait;
		//////////////////////////////////////////////////////////////////////////////////////////////////


		// for playback
		(
			~playerTask = Task({

				{
					if(~cueSpace[3][~cue] == 1, {
						var
						bufnum = ~cueSpace[1][~cue].asArray.interpret,
						freq = ~cueSpace[2][~cue].asArray.interpret,
						env = ~cueSpace[4][~cue],
						gain = ~mixSpace,
						pan = rrand(~cueSpace[5][~cue][0], ~cueSpace[5][~cue][1]),
						startPos =  ~cueSpace[6][~cue],

						// for particles
						prob = [0, 1].wchoose([1 - ~particleSpace[4], ~particleSpace[4]]),
						leg = ~particleSpace[3]

						;

						bufnum.size.do{|i|
							Synth(\playback, [\bufnum, bufnum[i], \gain, gain[0], \amp, env[2], \gate, ~gate[0], \pan, pan, \at, env[0], \rel, env[1], \dur, env[3], \startPos, startPos], ~pG);
						};

						freq.size.do{|i|
							Synth(\fsine, [\freq, freq[i], \gain, gain[1], \amp, env[2], \gate, ~gate[1], \pan, pan, \at, env[0], \rel, env[1], \dur, env[3]], ~sineG);

							Synth(\fsaw, [\freq, freq[i], \gain, gain[2], \amp, env[2], \gate, ~gate[2], \pan, pan, \at, env[0], \rel, env[1], \dur, env[3]], ~sawG);

							Synth(\klank, [\freq, freq[i],  \gain, gain[3], \amp, env[2], \gate, ~gate[3], \pan, pan, \at, env[0], \rel, env[1], \dur, env[3]], ~klankG);
						};

						// particles on the grid

						if(prob == 1, {
							var
							freq = ~particleList.asArray.interpret.choose,
							gain = ~mixSpace[4],
							pan = rrand(~pan[0], ~pan[1]),
							at = ~particleSpace[0],
							rel = ~particleSpace[1],
							amp =  ~particleSpace[2]*rrand(~amp[0], ~amp[1]);

							Synth(\fsine, [\at, at, \rel, rel, \amp, amp, \freq, freq, \gain, gain, \pan, pan, \dur, env[3], \leg, leg, \gate, ~gate[4]], ~g);
						}, {"no particles".postln});


						env[3].wait;
					}, {
						// small delay so we know the next step
						(1/8).wait;
						"silence".postln;
					});

				}.loop;
			});

			"player task defined".postln;
		);

		//////////////////////////////////////////////////////////////////////////////////////////////////
		// gui
		(1/10).wait;

		(
			~color = [
				Color.blue(1.0),
				Color.magenta(1.0),
				Color.yellow(1.0),
				Color.black,
				Color.white,
				Color.gray,
				Color.red,
				Color.green
			];

			~current = 0;
			~cue = 0;

			~mapToSlider = { |val, lo, hi| val.linlin(lo, hi, 0, 1) };
			~mapFromSlider = { |val, lo, hi| val.linlin(0, 1, lo, hi) };

			// meter
			~out =  Server.local.options.numOutputBusChannels;
			~wMeter = Window.new("scope",
				Rect(
					100,
					Window.screenBounds.height / 2 - 150,
					90,
					230
				)
			)
			.front
			.alwaysOnTop = true;
			~uMeter = ServerMeterView.new(s, ~wMeter, 0@0, 0, ~out);


			~buttonPlay = Button()
			.states_([
				["PLAY", ~color[2], ~color[0]],
				["STOP", ~color[3], ~color[6]]
			]);


			// slider unit
			(
				~sliderUnit = { |parent,
					min=(-1.0), max=1.0, step=0.01,
					currentVal=0.5, label="", color=nil,
					get=nil,            // should return a Number
					set=nil,            // called as set.(val)
					onChange=nil        // called as onChange.(val)
					|
					var spec, txt, sld, view, topRow;
					var readValues, updateText, applyValue, refresh;

					spec = ControlSpec(min, max, \linear, step);

					// parent must be a View (Window is OK because it acts as parent)
					view = CompositeView(parent);
					view.minHeight = 40;
					view.minWidth  = 40;

					topRow = HLayout(
						StaticText(view)
						.string_(label)
						.align_(\left),
						(txt = StaticText(view)
							.align_(\right))
					);
					topRow.spacing = 6;

					sld = Slider(view)
					.orientation_(\horizontal)
					.background_(color)
					.minHeight_(10);

					view.layout = VLayout(topRow, sld);
					view.layout.margins = 0;
					view.layout.spacing = 0;

					// helpers
					updateText = { |val|
						txt.string_(val.round(step).asString);
					};

					applyValue = { |val|
						var v = val.clip(min, max);
						sld.value_(v.linlin(min, max, 0, 1));
						updateText.(v);
					};

					readValues = {
						(val: spec.map(sld.value).round(step))
					};

					// init
					applyValue.(currentVal);

					// user -> write + callback
					sld.action_({
						var v = readValues.value[\val];
						updateText.(v);

						if(set.notNil) { set.(v) };
						if(onChange.notNil) { onChange.(v) };
					});

					// refresh function (pull from external getter)
					refresh = {
						if(get.notNil) {
							var v = get.();
							if(v.notNil) { applyValue.(v) };
						};
					};

					(
						view: view,
						slider: sld,
						text: txt,
						spec: spec,
						getValues: readValues,          // -> (val: number)
						setValue: { |v| applyValue.(v) },
						refresh: refresh
					);
				};
			);
			// env unit
			(
				~envUnit = { |parent,
					label="env",
					amp=1.0, at = 0.5, rel=0.5,
					grid=nil,
					onChange=nil   // <-- external action hook
					|
					var view, ev, header;
					var ampTxt, atTxt, relTxt;
					var updateValues, readValues;

					grid = grid ? Point(0.2, 0.2);

					view = CompositeView(parent);

					header = HLayout(
						StaticText(view).string_(label).minWidth_(60),

						(ampTxt = StaticText(view).minWidth_(70)),
						(atTxt  = StaticText(view).minWidth_(70)),
						(relTxt = StaticText(view).minWidth_(70))
					);

					ev = EnvelopeView(view)
					.drawLines_(true)
					.drawRects_(true)
					.resize_(5)
					.step_(0.01);

					view.layout = VLayout(header, ev);
					view.layout.margins = 4;
					view.layout.spacing = 4;

					ev.setEnv( Env([0, amp, 0], [at, rel], \wel) );
					ev.grid = grid;
					ev.gridOn_(true);
					ev.keepHorizontalOrder = true;

					ev.setEditable(0, false);
					ev.setEditable(2, false);

					// ---- value reader ----
					readValues = {
						var levels = ev.value[1];
						var times  = ev.value[0];
						(
							at:  times[1],
							rel: (1 - times[1]),
							amp: levels[1]
						);
					};

					// ---- update header ----
					updateValues = {
						var vals = readValues.value;
						ampTxt.string_("amp: " ++ vals[\amp].round(0.001));
						atTxt.string_("at: "   ++ vals[\at].round(0.001));
						relTxt.string_("rel: " ++ vals[\rel].round(0.001));
					};

					// ---- envelope edit action ----
					ev.action_({
						var vals = readValues.value;

						updateValues.value;

						if(onChange.notNil) {
							onChange.(vals[\at], vals[\rel], vals[\amp]);
						};
						ev.value.postln;
					});

					updateValues.value;

					(
						view: view,
						envView: ev,
						getValues: readValues,     // manual access
						setParams: { |newAt, newRel, newAmp|
							ev.setEnv(Env([0, newAmp, 0], [newAt, newRel], \wel));
							updateValues.value;
						}
					);
				};
			);


			(
				~rangeSliderUnit = { |parent,
					label="pan",
					min=(-1.0), max=1.0, step=0.01,
					initLo=nil, initHi=nil,
					get=nil,          // should return [lo, hi]
					set=nil,          // called as set.(lo, hi)
					onChange=nil,     // called as onChange.(lo, hi)
					bg=nil
					|
					var view, rs, loTxt, hiTxt, header;
					var updateText, readValues, applyValues, refresh;

					bg = bg ? Color.gray(0.2);

					initLo = initLo ? min;
					initHi = initHi ? max;

					view = CompositeView(parent);

					header = HLayout(
						(loTxt = StaticText(view).align_(\left).minWidth_(110)),
						StaticText(view).string_(label).align_(\center).minWidth_(60),
						(hiTxt = StaticText(view).align_(\right).minWidth_(110))
					);
					header.spacing = 6;

					rs = RangeSlider(view)
					.orientation_(\horizontal)
					.knobColor_(Color.gray(0.5))
					.background_(bg)
					.minWidth_(260);

					view.layout = VLayout(header, rs);
					view.layout.margins = 4;
					view.layout.spacing = 4;

					updateText = { |lo, hi|
						loTxt.string_("lo: " ++ lo.round(step).asString);
						hiTxt.string_("hi: " ++ hi.round(step).asString);
					};

					applyValues = { |lo, hi|
						var l = lo.clip(min, max);
						var h = hi.clip(min, max);
						if(h < l) { var tmp = l; l = h; h = tmp; }; // keep order

						rs.lo_(l.linlin(min, max, 0, 1));
						rs.hi_(h.linlin(min, max, 0, 1));
						updateText.(l, h);
					};

					readValues = {
						var lo = rs.lo.linlin(0, 1, min, max).round(step);
						var hi = rs.hi.linlin(0, 1, min, max).round(step);
						(lo: lo, hi: hi)
					};

					// init
					applyValues.(initLo, initHi);

					// user -> write + callback
					rs.action_({ |slider|
						var v = readValues.value;
						updateText.(v[\lo], v[\hi]);

						if(set.notNil) { set.(v[\lo], v[\hi]) };
						if(onChange.notNil) { onChange.(v[\lo], v[\hi]) };
					});

					// refresh function (pull from getter)
					refresh = {
						if(get.notNil) {
							var p = get.(); // [lo, hi]
							if(p.notNil and: { p.size >= 2 }) {
								applyValues.(p[0], p[1]);
							};
						};
					};

					(
						view: view,
						slider: rs,

						getValues: readValues,                      // -> (lo:, hi:)
						setParams: { |lo, hi| applyValues.(lo, hi) },// like slider's setValue
						setValue:  { |pair| applyValues.(pair[0], pair[1]) }, // convenience

						refresh: refresh
					);
				};
			);


			"gui functions loaded".postln;

			//////////////////////////////////////////////////////////////////////////////////////////////////
			// controls for synths

			// gates of synths
			~gate = Array.fill(5, {0});

			// sampler
			~samplerBtn = Button()
			.states_([
				["sampler off", Color.white, Color.gray],
				["sampler on", Color.white, Color.green]
			]);

			~samplerBtn.action_({ |butt|
				if (butt.value == 0, {~samplerOn = false;}, {~samplerOn = true;});
				butt.value.postln;
				if(~wP.isClosed.not, {~samplerSw.value});
			});


			~tSamples = TextField();
			~tSamples.string = ~cueSpace[1][~cue].asString;
			~cueSpace[1][~cue] = ~tSamples.string;
			~tSamples.action = { |item|
				"accept".postln;
				~cueSpace[1][~cue] = item.string;
			};


			// sine
			~sineBtn = Button()
			.states_([
				["sine off", Color.white, Color.gray],
				["sine on", Color.white, Color.green]
			]);


			~sineBtn.action_({ |butt|
				if (butt.value == 0, {~sineOn = false;}, {~sineOn = true;});
				butt.value.postln;
				if(~wP.isClosed.not, {~sineSw.value});
			});


			~tFreq = TextField();
			~tFreq.string = ~cueSpace[2][0].asString;
			~cueSpace[2][~cue] = ~tFreq.string;
			~tFreq.action = { |item|
				"accept".postln;
				~cueSpace[2][~cue] = item.string;
				~cueSpace[2][~cue].postln;
			};


			//saw
			~sawBtn = Button()
			.states_([
				["saw off", Color.white, Color.gray],
				["saw on", Color.white, Color.green]
			]);

			~sawBtn.action_({ |butt|
				if (butt.value == 0, {~sawOn = false;}, {~sawOn = true;});
				butt.value.postln;
				if(~wP.isClosed.not, {~sawSw.value});
			});

			//klank
			~klankBtn = Button()
			.states_([
				["klank off", Color.white, Color.gray],
				["klank on", Color.white, Color.green]
			]);

			~klankBtn.action_({ |butt|
				if (butt.value == 0, {~klankOn = false;}, {~klankOn = true;});
				butt.value.postln;
				if(~wP.isClosed.not, {~klankSw.value});
			});

			// particles
			~particleBtn = Button()
			.states_([
				["off", Color.white, Color.gray],
				["on", Color.white, Color.green]
			]);

			// this will be needed to save states in presets
			~particleBtn.action_({ |butt|
				if (butt.value == 0, {~particlesOn = false;}, {~particlesOn = true;});
				butt.value.postln;
				if(~wP.isClosed.not, {~switch.value});
			});

			~tTone = TextField();
			~tTone.string = ~particleList.asString;
			~particleList = ~tTone.value;
			~tTone.action = { |item|
				"accept".postln;
				~particleList = item.string;
			};


			~synthE = ~envUnit.(w,
				label:"amp",
				at: ~cueSpace[4][~cue][0],
				rel: ~cueSpace[4][~cue][1],
				amp: ~cueSpace[4][~cue][2],

				onChange: { |at, rel, amp|
					~cueSpace[4][~cue] = [at, rel, amp, ~cueSpace[4][~cue][3]];
					["stored:", ~cueSpace[4][~cue]].postln;
				}
			);

			~synthES = ~sliderUnit.(w,
				min: 1, max: 32, step: 1,
				currentVal: 16,
				label: "time scale",
				color: ~color[4],
				get: { ~cueSpace[4][~cue][3] },
				set: { |v| ~cueSpace[4][~cue][3] = v }
			);

			~samplerWindowS = ~sliderUnit.(w,
				min: 0.0, max: 1.0, step: 0.01,
				currentVal: 0.0,
				label: "needle position",
				color: ~color[4],
				get: { ~cueSpace[6][~cue] },
				set: { |v| ~cueSpace[6][~cue] = v }
			);

			// general panner
			~panS = ~rangeSliderUnit.(w,
				label:"pan",
				min:-1, max:1, step:0.01,
				initLo:~cueSpace[5][~cue][0], initHi:~cueSpace[5][~cue][1],
				get: { ~cueSpace[5][~cue] },
				set: { |lo, hi| ~cueSpace[5][~cue] = [lo, hi] },
				bg: ~color[0]
			);


			~cueStateButton = Button()
			.states_([
				["silence", Color.white, Color.gray],
				["cue active", Color.white, Color.green]
			]);

			~cueStateButton.action_({ |butt|
				if (butt.value == 0, {~cueOn = false; ~cueSpace[3][~cue] = 0;}, {~cueOn = true; ~cueSpace[3][~cue] = 1;});
				butt.value.postln;
				if(~wP.isClosed.not, {~activeSw.value});
			});


			"parameter gui loaded".postln;

			//////////////////////////////////////////////////////////////////////////////////////////////////
			// global variables

			~globalVarButton = Button()
			.states_([
				["variables", Color.black],
				["close variables", Color.red]
			]);

			~currentAmpVal = Array.fill(~amp.size, {|i| ~amp[i]});
			~currentPanVal = Array.fill(~pan.size, {|i| ~pan[i]});

			~memoryAmpVal = ~amp.collect { |arr| arr.copy };
			~memoryPanVal = ~pan.collect { |arr| arr.copy };

			~globalVarButton.action_({	|a|

				if(a.value == 1, {
					~globalText = Array.fill(3, {|i| StaticText()});
					~globalText[0].string = "---------------------------/edit amplitude & pan/---------------------------";
					~globalText[1].string = "Amp range (1.0 = 0db, 0.5 = -6db, 0.0 = -48db)";
					~globalText[2].string = "Pan range (max L = 0.0, max R = 1.0, center = 0.5)";

					~globalText[0].align_(\center).stringColor_(~color[0]);


					~sAmp = ~rangeSliderUnit.(w,
						label:"amp range",
						min:0.01, max:1.5, step:0.01,
						initLo:~currentAmpVal[0], initHi:~currentAmpVal[1],
						get: { ~currentAmpVal },
						set: { |lo, hi| ~currentAmpVal = [lo, hi]; ~amp = ~currentAmpVal; },
						bg: ~color[0]
					);


					~sPan = ~rangeSliderUnit.(w,
						label:"pan range",
						min:-1.0, max:1.0, step:0.01,
						initLo:~currentPanVal[0], initHi:~currentPanVal[1],
						get: { ~currentPanVal },
						set: { |lo, hi| ~currentPanVal = [lo, hi]; ~pan = ~currentPanVal; },
						bg: ~color[0]
					);


					~particleProbS = ~sliderUnit.(w,
						min: 0.0, max: 1.0, step: 0.01,
						currentVal: 16,
						label: "particle probability per step",
						color: ~color[4],
						get: { ~particleSpace[4] },
						set: { |v| ~particleSpace[4] = v }
					);

					~particleE = ~envUnit.(w,
						label:"particle envelope",
						at: ~particleSpace[0],
						rel: ~particleSpace[1],
						amp: ~particleSpace[2],

						onChange: { |at, rel, amp|
							~particleSpace = [at, rel, amp, ~particleSpace[3], ~particleSpace[4]];
							["stored:", ~particleSpace].postln;
						}
					);

					~particleES = ~sliderUnit.(w,
						min: 1, max: 4, step: 0.1,
						currentVal: 1,
						label: "legato",
						color: ~color[4],
						get: { ~particleSpace[3] },
						set: { |v| ~particleSpace[3] = v }
					);

					~particleProbS[\setValue].(~particleSpace[4]);
					~particleE[\setValue].(~particleSpace[0], ~particleSpace[1], ~particleSpace[2]);
					~particleES[\setValue].(~particleSpace[3]);

					(
						g = Window(
							"global variables",
							Rect(
								Window.screenBounds.width / 2 + 250,
								Window.screenBounds.height / 2 - 150,
								500,
								300
							)
						)
					)
					.alwaysOnTop_(true)
					.onClose_({a.value = 0})
					.front
					.layout_(
						VLayout(
							~globalText[0],
							~globalText[1],
							~sAmp[\view],
							~globalText[2],
							~sPan[\view],
							~particleProbS[\view],
							~particleE[\view],
							~particleES[\view],
					));

					~updateSlidersForState.(0); // Start with first set visible


				},{
					if(g.isClosed.not == true, {g.close;},{"error closing window".postln});
				});
			});


			// mixer window

			~mixerButton = Button()
			.states_([
				["open mixer", Color.black],
				["close mixer", Color.red]
			]);

			~mixerButton.action_({	|a|

				if(a.value == 1, {

					~samplerAmpS = ~sliderUnit.(w,
						min: 0.001, max: 1.5, step: 0.001,
						currentVal: 16,
						label: "sampler amp",
						color: ~color[4],
						get: { ~mixSpace[0] },
						set: { |v| ~mixSpace[0] = v; ~pG.set(\gain, v)}
					);

					~sineAmpS = ~sliderUnit.(w,
						min: 0.001, max: 1.5, step: 0.001,
						currentVal: 16,
						label: "sine amp",
						color: ~color[4],
						get: { ~mixSpace[1] },
						set: { |v| ~mixSpace[1] = v; ~sineG.set(\gain, v)}
					);

					~sawAmpS = ~sliderUnit.(w,
						min: 0.001, max: 1.5, step: 0.001,
						currentVal: 16,
						label: "saw amp",
						color: ~color[4],
						get: { ~mixSpace[2] },
						set: { |v| ~mixSpace[2] = v; ~sawG.set(\gain, v)}
					);

					~klankAmpS = ~sliderUnit.(w,
						min: 0.001, max: 1.5, step: 0.001,
						currentVal: 16,
						label: "klank amp",
						color: ~color[4],
						get: { ~mixSpace[3] },
						set: { |v| ~mixSpace[3] = v; ~klankG.set(\gain, v)}
					);

					// these need to be adjusted to the right par space
					~particleAmpS = ~sliderUnit.(w,
						min: 0.001, max: 1.5, step: 0.001,
						currentVal: 16,
						label: "particle amp",
						color: ~color[4],
						get: { ~mixSpace[4] },
						set: { |v| ~mixSpace[4] = v; ~g.set(\gain, v)}
					);

					// recall again
					~samplerAmpS[\setValue].(~mixSpace[0]);
					~sineAmpS[\setValue].(~mixSpace[1]);
					~sawAmpS[\setValue].(~mixSpace[2]);
					~klankAmpS[\setValue].(~mixSpace[3]);
					~particleAmpS[\setValue].(~mixSpace[4]);

					(
						~mixW = Window(
							"mixer",
							Rect(
								Window.screenBounds.width / 2 + 250,
								Window.screenBounds.height / 2 - 150,
								500,
								300
							)
						)
					)
					.alwaysOnTop_(true)
					.onClose_({a.value = 0})
					.front
					.layout_(
						VLayout(
							~samplerAmpS[\view],
							~sineAmpS[\view],
							~sawAmpS[\view],
							~klankAmpS[\view],
							~particleAmpS[\view]
					));
				}, {
					if(~mixW.isClosed.not == true, {~mixW.close;},{"error closing window".postln});
				});
			});

			//////////////////////////////////////////////////////////////////////////////////////////////////////
			// key configuartion button

			~keyConfButton = Button()
			.states_([
				["key configuration", ~color[3]],
				["close key configuration", ~color[6]]
			]);


			~keyCheck = r { |inval|
				(~keyText[1].string = "press forward button once");
				~keyText[1].stringColor_(~color[3]).background_(~color[1]);
				~forwardBtn = inval.yield;
				postln([~forwardBtn]);
				(~keyText[1].string = "press backward button once");
				~keyText[1].stringColor_(~color[3]).background_(~color[2]);
				~backwardBtn = inval.yield;

				while { ~backwardBtn == ~forwardBtn } {
					~keyText[1].string = "choose a DIFFERENT backward button";
					~keyText[1].stringColor_(~color[3]).background_(~color[6]);
					~backwardBtn = inval.yield;
				};

				postln([~backwardBtn]);
				~keyText[1].stringColor_(~color[3]).background_(~color[7]);
				(~keyText[1].string = "press any button to close").yield;
				~wKey.close;
			};


			~keyConfButton.action_({ |a|
				if(a.value == 1, {

					~keyCheck.reset;

					~keyNum = Array.fill(2, {|i| StaticText()});
					~keyNum[0].string = ~forwardBtn;
					~keyNum[1].string = ~backwardBtn;

					~keyText = Array.fill(4, {|i| StaticText()});
					~keyText[0].string = "Follow the instructions to calibrate cue buttoons on your keyboard or pedal. If no change is needed, close the window without pressing a new button.";
					~keyText[1].string = "press any key to start the calibration process";
					~keyText[2].string = "Current forwards button";
					~keyText[3].string = "Current backwards button";

					~keyText[1].background_(~color[4]).stringColor_(~color[3]).align_(\center);
					~keyText[2].background_(~color[1]);
					~keyNum[0].background_(~color[3]).stringColor_(~color[4]).align_(\center);
					~keyText[3].background_(~color[2]);
					~keyNum[1].background_(~color[3]).stringColor_(~color[4]).align_(\center);


					~wKey = Window("key check")
					.layout_(VLayout(~keyText[0], ~keyText[1], HLayout(~keyText[2], ~keyNum[0], ~keyText[3], ~keyNum[1])))
					.onClose_({a.value = 0})
					.alwaysOnTop_(true)
					.front;

					(
						~checkKeyVal = Task{
							{

								{
									if(~wKey.isClosed.not) {
										~keyText[1];
										~keyNum[0].string = ~forwardBtn;
										~keyNum[1].string = ~backwardBtn;
									}
								}.defer;

								0.1.wait;
							}.loop
						}.play;
					);


					~wKey.view.keyDownAction = ({
						// the args must stay in this order to be properly read
						|view, char, modifiers, unicode, keycode|

						~keyCheck.next(keycode);
					});
				},{
					if(~wKey.isClosed.not == true, {~wKey.close;},{"error closing window".postln});
				});

			});



			~menu = PopUpMenu();
			~currentCueArray = Array.fill(~cueNum, {|i| i});
			~menu.items = ~currentCueArray;

			~menu.action = ({ |menu|
				~cue = menu.value;
				~currentCueArray[menu.value].postln;

				~activeText.string = if(~cueSpace[3][~cue] == 0, {"silence"}, {"cue active"});

	/*			~samplerMenu.value = ~cueSpace[1][~cue];*/
				~tSamples.value = ~cueSpace[1][~cue];

				~tFreq.value = ~cueSpace[2][~cue];
				~cueStateButton.value = ~cueSpace[3][~cue];
				~synthE[\setParams].(~cueSpace[4][~cue][0], ~cueSpace[4][~cue][1], ~cueSpace[4][~cue][2]);
				~synthES[\setValue].(~cueSpace[4][~cue][3]);
				~panS[\setValue].(~cueSpace[5][~cue]);

				~samplerWindowS[\setValue].(~cueSpace[6][~cue]);
			});

			////////////////////////////////////////////////////////////////////////
			// playing slot and pop up window for display

			~buttonPlay.action_({ |butt|
				if(butt.value == 1,{

					// make synth group
					~g = Group.new;
					~pG = Group.new;
					~sineG = Group.new;
					~sawG = Group.new;
					~klankG = Group.new;


					~guides = Array.fill(8, {
						StaticText()
						.background_(Color.white)
						.stringColor_(Color.black)
						.font_(Font("Arial", 20))
						.minWidth_(30)
					});

					~guides[0].string = "particles on";
					~guides[1].string = "sampler on";
					~guides[2].string = "sine on";
					~guides[3].string = "saw on";
					~guides[4].string = "klank on";

					~guides[5].string = "current sample:";
					~guides[6].string = "current particle freq array:";
					~guides[7].string = "current synth freq:";


					~cueText = StaticText()
					.string_("current cue")
					.background_(Color.blue)
					.stringColor_(Color.yellow)
					.font_(Font("Arial", 20))
					.align_(\center);

					~sampleText = StaticText()
					.string_("sample")
					.background_(Color.blue)
					.stringColor_(Color.yellow)
					.font_(Font("Arial", 20))
					.align_(\center);

					~particleText = StaticText()
					.string_("particles")
					.background_(Color.blue)
					.stringColor_(Color.yellow)
					.font_(Font("Arial", 20))
					.align_(\center);


					~freqText = StaticText()
					.string_("freq")
					.background_(Color.blue)
					.stringColor_(Color.yellow)
					.font_(Font("Arial", 20))
					.align_(\center);


					~activeText = StaticText()
					.string_("cue active")
					.background_(Color.blue)
					.stringColor_(Color.yellow)
					.font_(Font("Arial", 20))
					.align_(\center);

					~activeSw = {
						if(~cueOn == false, {
							"silence".postln;
							~activeText.string_("silence");
						}, {
							"cue active".postln;
							~activeText.string_("cue active");
						})
					};

					~activeSw.value;

					~switch = {
						if(~particlesOn == false, {
							"particles off".postln;
							~guides[0].string_("particles off")
							.background_(Color.gray)
							.stringColor_(Color.black);
/*							t.stop;*/
							~gate[4] = 0;
							~g.set(\amp, ~gate[4]);
						}, {
							"particles on".postln;
/*							t.start;*/
							~guides[0].string_("particles on")
							.background_(Color.white)
							.stringColor_(Color.black);
							~gate[4] = 1;
							~g.set(\amp, ~gate[4]);
						});
					};


					~switch.value;

					~samplerSw = {
						if(~samplerOn == false, {
							"sampler off".postln;
							~guides[1].string_("sampler off")
							.background_(Color.gray)
							.stringColor_(Color.black);
							~gate[0] = 0;
							~pG.set(\amp, ~gate[0]);
						}, {
							"sampler on".postln;
							~guides[1].string_("sampler on")
							.background_(Color.white)
							.stringColor_(Color.black);
							~gate[0] = 1;
							~pG.set(\amp, ~gate[0]);
						});
					};

					~samplerSw.value;


					~sineSw = {
						if(~sineOn == false, {
							"sine off".postln;
							~guides[2].string_("sine off")
							.background_(Color.gray)
							.stringColor_(Color.black);
							~gate[1] = 0;
							~sineG.set(\amp, ~gate[1]);
						}, {
							"sine on".postln;
							~guides[2].string_("sine on")
							.background_(Color.white)
							.stringColor_(Color.black);
							~gate[1] = 1;
							~sineG.set(\amp, ~gate[1]);
						});
					};

					~sineSw.value;

					~sawSw = {
						if(~sawOn == false, {
							"saw off".postln;
							~guides[3].string_("saw off")
							.background_(Color.gray)
							.stringColor_(Color.black);
							~gate[2] = 0;
							~sawG.set(\amp, ~gate[2]);
						}, {
							"saw on".postln;
							~guides[3].string_("saw on")
							.background_(Color.white)
							.stringColor_(Color.black);
							~gate[2] = 1;
							~sawG.set(\amp, ~gate[2]);
						});
					};

					~sawSw.value;

					~klankSw = {
						if(~klankOn == false, {
							"klank off".postln;
							~guides[4].string_("klank off")
							.background_(Color.gray)
							.stringColor_(Color.black);
							~gate[3] = 0;
							~klankG.set(\amp, ~gate[3]);
						}, {
							"klank on".postln;
							~guides[4].string_("klank on")
							.background_(Color.white)
							.stringColor_(Color.black);
							~gate[3] = 1;
							~klankG.set(\amp, ~gate[3]);
						});
					};

					~klankSw.value;

					~playerTask.start;
					~limitSynth = Synth(\limit);

					(
						r = Task {
							{

								{
									if(~wP.isClosed.not) {
										~cueText.string = ~cue.asString;
										~particleText.string = ~particleList;
										~sampleText.string = ~cueSpace[1][~cue].asString;
										~freqText.string = 	~cueSpace[2][~cue].asString;
									}
								}.defer;

								0.1.wait;
							}.loop

						}.play;
					);

					~wP = Window(
						"perform",
						Rect(
							Window.screenBounds.width / 2 - 300,
							Window.screenBounds.height / 2 - 300,
							600,
							600
						)
					)
					.alwaysOnTop_(true)
					.onClose_({s.freeAll; ~playerTask.stop; t.stop; ~buttonPlay.value = 0;})
					.layout_(
						VLayout(
							~cueText,
							~activeText,
							HLayout(~guides[1], ~guides[2], ~guides[3], ~guides[4]),
							HLayout(~guides[5], ~sampleText),
							HLayout(~guides[7], ~freqText),
							~guides[0],
							HLayout(~guides[6], ~particleText),
						)
					)
					.front;



					~wP.view.keyDownAction = ({
						// the args must stay in this order to be properly read
						|view, char, modifiers, unicode, keycode|
						if(keycode == ~forwardBtn,
							{postln(["up"]);
								~current = (~current+1).clip(0,~cueSpace[0].size - 1);
								~cue = ~current;
								postln(["cue: ", ~cue]);
								~menu.value_(~current);
/*								~samplerMenu.value_(~cueSpace[1][~cue]);*/
								~tSamples.value_(~cueSpace[1][~cue]);
								~tFreq.value = ~cueSpace[2][~cue];
								~cueStateButton.value = ~cueSpace[3][~cue];
								~activeText.string = if(~cueSpace[3][~cue] == 0, {"silence"}, {"cue active"});


								~synthE[\setParams].(~cueSpace[4][~cue][0], ~cueSpace[4][~cue][1], ~cueSpace[4][~cue][2]);
								~synthES[\setValue].(~cueSpace[4][~cue][3]);
								~panS[\setValue].(~cueSpace[5][~cue]);
								~samplerWindowS[\setValue].(~cueSpace[6][~cue]);
							},
							{
								if(keycode == ~backwardBtn,
									{postln(["down"]);
										~current = (~current-1).clip(0,~cueSpace[0].size);
										~cue = ~current;
										postln(["cue: ", ~cue]);
										/*									postln(["density: ", ~density[~cue][3]]);*/
										~menu.value_(~current);
/*										~samplerMenu.value_(~cueSpace[1][~cue]);*/
										~tSamples.value_(~cueSpace[1][~cue]);
										//???????????????????????????
										// or should this be current instead of cue????????????

										~tFreq.value = ~cueSpace[2][~cue];
										~cueStateButton.value = ~cueSpace[3][~cue];
										~activeText.string = if(~cueSpace[3][~cue] == 0, {"silence"}, {"cue active"});

										~synthE[\setParams].(~cueSpace[4][~cue][0], ~cueSpace[4][~cue][1], ~cueSpace[4][~cue][2]);
										~synthES[\setValue].(~cueSpace[4][~cue][3]);
										~panS[\setValue].(~cueSpace[5][~cue]);
										~samplerWindowS[\setValue].(~cueSpace[6][~cue]);
										/*									~tTone.string = ~toneName[~cue];*/
									},
									{postln(["invalid"])}
								);
							}
						);
					});



				},{
					t.stop;
					s.freeAll;
					~wP.close;
				});
			});


			///////////////////////////////////////////////////////////////////////////////////////////////////
			// cue buttons

			// ====================================================================
			// ADD BUTTON  (fixed, safe, consistent arrays)
			// ====================================================================
			~addButton = Button().states_([["+", Color.black]]);

			~addButton.action_({
				var newCueIndex;

				// advance cue index
				newCueIndex = ~cue + 1;

				// ------------------------------
				// Insert NEW CUE at newCueIndex
				// ------------------------------
				~cueSpace[0] = ~cueSpace[0].insert(newCueIndex, ~pause.copy);
				~cueSpace[1] = ~cueSpace[1].insert(newCueIndex, [0].asString);
/*				~samplerMenu.value = 0;*/
				~tSamples.value_([0].asString);

				~cueSpace[2] = ~cueSpace[2].insert(newCueIndex, [160].asString);
				~tFreq.value = [160].asString;

				~cueSpace[3] = ~cueSpace[3].insert(newCueIndex, 0);
				~cueStateButton.value = 0;

				~cueSpace[4] = ~cueSpace[4].insert(newCueIndex, [0.5, 0.5, 1, 16]);
				~synthE[\setParams].(0.5, 0.5, 1);
				~synthES[\setValue].(16);

				~cueSpace[5] = ~cueSpace[5].insert(newCueIndex, [-0.5, 0.5]);
				~panS[\setParams].(-0.5, 0.5);

				~cueSpace[6] = ~cueSpace[6].insert(newCueIndex, 0.0);
				~samplerWindowS[\setValue].(0.0);

				// Update cue index
				~cue = newCueIndex.clip(0, ~cueSpace[0].size - 1);

				// Rebuild cue index array
				~currentCueArray = Array.series(~cueSpace[0].size, 0, 1);

				// Update menu
				~menu.items = ~currentCueArray;
				~menu.value = ~cue;

				~cueNum = ~currentCueArray.size;

				("Added cue at index " ++ ~cue).postln;
			});


			// ====================================================================
			// TAKE BUTTON (fixed, safe, consistent arrays)
			// ====================================================================
			~takeButton = Button().states_([["-", Color.black]]);

			~takeButton.action_({
				if (~cue == 0) {
					"first cue, cannot remove".postln;
					^nil;
				};

				// Remove arrays at current index
				~cueSpace[0].removeAt(~cue);
				~cueSpace[1].removeAt(~cue);
				~cueSpace[2].removeAt(~cue);
				~cueSpace[3].removeAt(~cue);
				~cueSpace[4].removeAt(~cue);
				~cueSpace[5].removeAt(~cue);
				~cueSpace[6].removeAt(~cue);

				// Move cue pointer back
				~cue = (~cue - 1).clip(0, ~cueSpace[0].size - 1);

				// Rebuild cue index array
				~currentCueArray = Array.series(~cueSpace[0].size, 0, 1);

				// Update GUI
				~menu.items = ~currentCueArray;
				~menu.value = ~cue;

				// formatting callbacks
				~formatToneList.value;
				~makeToneList.value;

				~cueNum = ~currentCueArray.size;

				("Removed cue, now at " ++ ~cue).postln;
			});




			///////////////////////////////////////////////////////////////////////////////////////////////////
			// for savinbg presets
			~saveButton = Button()
			.states_([["save preset"]]);



			~saveButton.action_({
				(
					FileDialog({ |path|
						[
							~cueSpace,
							~sampleList,
							~currentCueArray,
							~cueNum,
							~amp,
							~pan,
							~forwardBtn,
							~backwardBtn,

							~samplerOn,
							~sineOn,
							~sawOn,
							~klankOn,
							~particlesOn,
							~cueOn,

							~particleList,
							~particleSpace,
							~mixSpace


/*							~sampleList,
							~deviation,
							~amp,
							~pan,
							~currentCueArray,
							~forwardBtn,
							~backwardBtn,
							~cueSpace,
							~cueNum*/


						].writeArchive(path);

						~currentPath = path;
						~tPreset.string = ~currentPath.asString;

						Window.closeAll;
						s.reboot;
						s.doWhenBooted({~func.value;});
					},
					fileMode: 0,
					acceptMode: 1,
					stripResult: true,
					path: ~path ++ "/presets");
				);
				"saved".postln;
			});

			~loadButton = Button()
			.states_([["load preset"]]);

			~loadButton.action_({
				(
					FileDialog({ |path|
						~reader = Object.readArchive(path);
						~reader.postln;
/*						~tTone.string = ~toneName[~current];*/
						~tPreset.string = path.basename.asString;
						postln("Selected file:" + path);
						postln("File type is:" + File.type(path));
						~currentPath = path;
						~tPreset.string = ~currentPath.asString;

						Window.closeAll;
						s.reboot;
						s.doWhenBooted({~func.value;});

					},
					fileMode: 0,
					acceptMode: 0,
					stripResult: true,
					path: ~path ++ "/presets");
				);
				"retrieved".postln;
			});


			~tPreset = StaticText()
			.background_(~color[4])
			.stringColor_(~color[3])
			.align_(\center);

			~tPreset.string = ~currentPath.asString;

			~seperator = Array.fill(10, {StaticText()});
			~seperator[0].string = "/edit cue/---------------------------";
			~seperator[1].string = "/play/---------------------------";
			~seperator[2].string = "---------------------------/save & load presets/---------------------------";
			~seperator[3].string = "---------------------------/edit play keys/---------------------------";
			~seperator[4].string = "---------------------------/utils/---------------------------";
			~seperator[5].string = "/sine/";
			~seperator[6].string = "/saw/";
			~seperator[7].string = "/klank/";
			~seperator[8].string = "---------------------------/synthesis/---------------------------";
			~seperator[9].string = "---------------------------/random sine particles/---------------------------";

			~seperator.size.do{|i|
				~seperator[i].stringColor_(~color[0]).align_(\center);
			};

			~seperator[0].align_(\left);
			~seperator[1].align_(\left);
			~seperator[5].align_(\left);
			~seperator[6].align_(\left);
			~seperator[7].align_(\left);


			(
				~wM = Window(
					"player",
					Rect(
						Window.screenBounds.width / 2 - 250,
						Window.screenBounds.height / 2 - 150,
						600,
						300
					)
				)
			)
			.alwaysOnTop_(true)
			.onClose_({~checkGlobalVal.reset; ~checkGlobalVal.stop;
				s.freeAll;})
			.front
			.layout_(
				VLayout(
					~seperator[2],
					~tPreset,
					HLayout(~loadButton, ~saveButton),
					~seperator[1],
					~buttonPlay,
					~seperator[0],
					~menu,
					HLayout(~takeButton, ~addButton),
					~seperator[8],
					HLayout(
						~samplerBtn,
						~sineBtn,
						~sawBtn,
						~klankBtn,
					),
					~cueStateButton,
					HLayout(StaticText().string_("sample numbers as array:"), ~tSamples),
					HLayout(StaticText().string_("freq as float array:"), ~tFreq),
					~synthE[\view],
					~synthES[\view],
					~samplerWindowS[\view],
					~panS[\view],
					~seperator[9],
					HLayout(~particleBtn, StaticText().string_("particle freq:"), ~tTone, ~globalVarButton),
					~seperator[4],
					~mixerButton,
					/*				~seperator[3],*/
					~keyConfButton

			));

		);

		if(~samplerOn = true, {~samplerBtn.value = 1}, {~samplerBtn.value = 0});
		if(~sineOn = true, {~sineBtn.value = 1}, {~sineBtn.value = 0});
		if(~sawOn = true, {~sawBtn.value = 1}, {~sawBtn.value = 0});
		if(~klankOn = true, {~klankBtn.value = 1}, {~klankBtn.value = 0});
/*		if(~cueOn = true, {~cueStateButton.value = 1}, {~cueStateButton.value = 0});*/
		if(~particlesOn = true, {~particleBtn.value = 1}, {~particleBtn.value = 0});
/*
		~activeSw.value;
		~switch.value;
		~samplerSw.value;
		~sineSw.value;
		~sawSw.value;
		~klankSw.value;*/
	};
	~func.value;
};
);
);
