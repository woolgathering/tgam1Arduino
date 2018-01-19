Server.local.makeWindow;
Server.local.options.memSize = 16384;

// do this first
(
Routine.run({
	Server.local.boot;
	0.1.wait;
	Server.local.scope;
});
)

// main
(
var infoArray = [
	[thisProcess.nowExecutingPath.dirname +/+ "sounds/cunningham2.wav", 120.144, 4096],
	[thisProcess.nowExecutingPath.dirname +/+ "sounds/mable.wav", 2.1, 4096],
	[thisProcess.nowExecutingPath.dirname +/+ "sounds/tcp_d2_09_phonetic_alphabet_nato_irdial.wav", 8.0, 4096],
	[thisProcess.nowExecutingPath.dirname +/+ "sounds/piano.wav", 27.8, 4096],  // 27.8
	[thisProcess.nowExecutingPath.dirname +/+ "sounds/piano.wav", 130.2, 4096],
	[thisProcess.nowExecutingPath.dirname +/+ "sounds/earth.wav", 7.0, 8192],
	[thisProcess.nowExecutingPath.dirname +/+ "sounds/piano.wav", 130.2, 8192]
];
var pollVals, testSynth, convSynthKlank, convSynth, conv, conv2, conv3;
var makeNotes, makeKernalArray, loadBuffs, freeBuffs, runMain;
var buffArray, kernalArray;
var deltaBus, thetaBus, alphaBus, betaBus;
var pollRoutine;
var debug = 0, plotKernals = false;

// ATS file
~atsFile = AtsFile.new(thisProcess.nowExecutingPath.dirname +/+ "lib/ats/two.ats").load;

// data busses
deltaBus = Bus.control(s, 1);
thetaBus = Bus.control(s, 1);
alphaBus = Bus.control(s, 1);
betaBus = Bus.control(s, 1);


// synthDefs...
pollVals = SynthDef(\pollVals, {arg atsBuff, totalDur = 120.0, timeThresh = 1.0, ampThresh = 0.3, inBus = 2;
	var delta, theta, alpha, beta, gamma, waves, waveSum;
	var deltaPartials, thetaPartials, alphaPartials, betaPartials;
	var in, inAmp, inTrig, timer;
	var pointer = LFSaw.kr(~atsFile.sndDur.reciprocal, 1, 0.5, 0.5);

	deltaPartials = Array.series(38,1,1);
	thetaPartials = Array.series(15,39,1);
	alphaPartials = Array.series(20,55,1);
	betaPartials = Array.series(41,76,1);

	delta = (AtsAmp.kr(~atsFile.bufnum, deltaPartials, pointer)).sum;
	theta = (AtsAmp.kr(~atsFile.bufnum, thetaPartials, pointer)).sum;
	alpha = (AtsAmp.kr(~atsFile.bufnum, alphaPartials, pointer)).sum;
	beta = (AtsAmp.kr(~atsFile.bufnum, betaPartials, pointer)).sum;

	// normalizeSum the values
	waveSum = [delta, theta, alpha, beta].sum;
	waves = [delta, theta, alpha, beta]/waveSum;

	// write the values to a bus
	Out.kr(deltaBus, waves[0]);
	Out.kr(thetaBus, waves[1]);
	Out.kr(alphaBus, waves[2]);
	Out.kr(betaBus, waves[3]);
}).send(s);

convSynth = CtkSynthDef(\convSynth, {arg dur = 10.0, amp, buffer, lpCutoff = 2000, den = 2000, panFreq = 1.0, centerFreq = 50, outBus = 2, mix = 1.0, gain = 1.0, mS = 1, alpha = 0.5, beta = 0.5, delta = 0.5, theta = 0.5;
	var ampEnvGen;
	var sigL, sigR, convSig, klankSig, out;
	var convSigMono, klankSigMono;
	var klankSigExciter, convSigExciter;
	var panPos;
	var harm, amps, ring;
	var deltaAmpGood, deltaAmp;
	var mixGood, centerFreqGood, gainGood, stretchGood, stretch;
	var ampStretchGood, ampStretch;

	// in
	mixGood = (alpha/1)* 3;
	mix = Gate.kr(mixGood, CheckBadValues.kr(mixGood)<=0);
	// mix = Clip.kr(mix, 0, 1);
	// mix = mix*Rand(0.5, 1.5);

	deltaAmpGood = Lag.kr(delta.reciprocal, 2.0);
	deltaAmp = Gate.kr(deltaAmpGood, CheckBadValues.kr(deltaAmpGood)<=0);

	gainGood = theta * 4.5;
	gain = Gate.kr(gainGood, CheckBadValues.kr(gainGood)<=0);

	stretchGood = beta + 0.8;
	stretch = Gate.kr(stretchGood, CheckBadValues.kr(stretchGood)<=0);


	ampStretchGood = Lag.kr(alpha/beta, 5.0);
	ampStretch = Gate.kr(ampStretchGood, CheckBadValues.kr(ampStretchGood)<=0);
	ampStretch = ampStretch*Rand(1.0, 2.0);

	// sounds lame... could do better
	// centerFreqGood = Lag.kr((theta/delta)*2*centerFreq, 1.0);
	// centerFreq = Gate.kr(centerFreqGood, CheckBadValues.kr(centerFreqGood)<=0);

	// note envelope
	ampEnvGen = EnvGen.kr(
		Env([0,1,1,0], [1,15,1].normalizeSum),
		levelScale: amp*0.2,
		timeScale: dur
	);

	// complex source
	sigL = LPF.ar(Dust2.ar(den), lpCutoff);
	sigR = LPF.ar(Dust2.ar(den), lpCutoff);

	// filter!
	convSig = Convolution2.ar([sigL, sigR], buffer, framesize: 4096);

	// klank stuff
	harm = [0.51, 1, 2.01, 2.98, 4.02, 5.01, 6.02, 6.99, 8.0, 9.03, 9.97] * stretch;
	amps = [0.7, 1.0, 1.0, 0.9, 0.8, 0.71, 0.82, 0.9, 0.7, 0.6, 0.6, 0.55] * (0.015*ampStretch);
	ring = Array.rand(11, 0.2, 1.5);

	// panning..
	panPos = LFNoise1.kr(panFreq);

	// klank me
	klankSig = DynKlank.ar(`[harm, amps, ring], HPF.ar(HPF.ar(convSig, 50), 50), centerFreq);
	klankSigExciter = HPF.ar(
		(HPF.ar(klankSig, (centerFreq*64).min(SampleRate.ir*0.5)) * 3.0).softclip,
		(centerFreq*128).min(SampleRate.ir*0.5),
		2.0);
	klankSig = Mix.new([klankSig, klankSigExciter]) * mix;
	klankSig = Rotate2.ar(klankSig[0], klankSig[1], panPos);
	klankSigMono = Pan2.ar(klankSig[0], panPos);
	klankSig = Select.ar(mS, [klankSigMono, klankSig]);

	// conv me
	convSigExciter = HPF.ar(
		(HPF.ar(convSig, (centerFreq*64).min(SampleRate.ir*0.5)) * 3.0).softclip,
		(centerFreq*128).min(SampleRate.ir*0.5),
		2.0
	);
	convSig = Mix.new([convSig, convSigExciter]) * (1.0-mix);
	convSig = Rotate2.ar(convSig[0], convSig[1], panPos);
	convSigMono = Pan2.ar(convSig[0], panPos);
	convSig = Select.ar(mS, [convSigMono, convSig]);

	// make me stereo
	out = Mix.new([convSig*1.5, klankSig]);
	out = (out*gain).softclip;
	out = Mix.new([FreeVerb2.ar(out[0],out[1], 1.0, 1.0, 0.5), out]);
	Out.ar(outBus, (out*ampEnvGen*deltaAmp).softclip);
}).send(s);


// kernal stuff.......................
// make kernal function
makeKernalArray = {arg localBuffArray, localSize;
	var win, makeKernalFunc;
	var localKernal;
	var localArray;
	var normalize;

	// this function must live inside this in order for it to work?!
	normalize = { arg kernel, maxAmp = 1.0;
		var realSignal, imagSignal, cosTable, fftSignal, fftMagnitude, fftPhase, maxMag;
		var scale;
		var ifftKernel;

		// FFT analysis here!
		realSignal = kernel.as(Signal);
		imagSignal = Signal.newClear(kernel.size);
		cosTable = Signal.fftCosTable(kernel.size);
		fftSignal = fft(realSignal, imagSignal, cosTable);
		fftMagnitude = fftSignal.magnitude;

		// reset phase to linear
		fftPhase = Array.series(kernel.size, 0, -pi);

		// compute max magnitude and display
		maxMag = fftMagnitude.maxItem;
		"un-normalised maximum magnitude = ".post;
		maxMag.ampdb.post;
		" dB".postln;

		// normalise phase
		ifftKernel = ifft(
			fftMagnitude.as(Signal) * (fftPhase.cos.as(Signal)),
			fftMagnitude.as(Signal) * (fftPhase.sin.as(Signal)),
			cosTable
		);
		ifftKernel = ifftKernel.real;

		// normalise gain
		scale = maxMag.reciprocal * maxAmp;
		(scale * ifftKernel).as(Array);
	};

	// make the kernal
	win = Signal.hanningWindow(localSize);
	win = win.as(Array);
	localBuffArray.loadToFloatArray(action: {arg array;
		~localKernal = win*array;
		~localKernal = normalize.value(~localKernal);

		// debug me
		if(debug == 2, {'inFunction: '.post; ~localKernal.postln;}, {});
	});

	// return
	~localKernal;
};

// buffers ..oOo..oOo..oOo..oOo..oOo..oOo..oOo
buffArray = Array.fill(infoArray.size, {arg i;
	CtkBuffer.playbuf(
		infoArray[i][0],                  // path
		(infoArray[i][1] * 44100).floor,  // startFrame
		infoArray[i][2],                  // size
		channels: 0                       // just load one channel (left)
	);
});

loadBuffs = {arg localBuffArray;
	localBuffArray.do({arg localBuff;  // load kernal buffers
		localBuff.load;
	});
};

freeBuffs = {arg localBuffArray;
	localBuffArray.do({arg localBuff;
		localBuff.free;     // free only the kernal buffers
	})
};


///////
runMain = {
	Routine.run({
		var ratio;
		0.5.wait;
		Synth(\pollVals, addAction: \addToTail);

		conv = Synth(\convSynth, [
			\dur, ~atsFile.sndDur,
			\amp, 0.8,
			\buffer, [b,c,d].choose.bufnum,
			\den, 15000,
			\panFreq, 0.05,
			\centerFreq, 30,
			\gain, 1.0,
			\mS, 0,
			\lpCutoff, 15000,
			\outBus, 0,
			\mix, 0.0
			]
		);
		conv.map(\alpha, alphaBus);
		conv.map(\beta, betaBus);
		conv.map(\delta, deltaBus);
		conv.map(\theta, thetaBus);

		conv2 = Synth(\convSynth, [
			\dur, ~atsFile.sndDur,
			\amp, 0.7,
			\buffer, [b,c,d].choose.bufnum,
			\den, 15000,
			\panFreq, 0.33,
			\centerFreq, 46,
			\gain, 1.0,
			\mS, 1,
			\lpCutoff, 15000,
			\outBus, 0,
			\mix, 0.0
			]
		);
		conv2.map(\alpha, alphaBus);
		conv2.map(\beta, betaBus);
		conv2.map(\delta, deltaBus);
		conv2.map(\theta, thetaBus);

		conv3 = Synth(\convSynth, [
			\dur, ~atsFile.sndDur,
			\amp, 0.7,
			\buffer, [b,c,d].choose.bufnum,
			\den, 15000,
			\panFreq, 0.33,
			\centerFreq, 33,
			\gain, 1.0,
			\mS, 1,
			\lpCutoff, 15000,
			\outBus, 0,
			\mix, 0.0
			]
		);
		conv3.map(\alpha, alphaBus);
		conv3.map(\beta, betaBus);
		conv3.map(\delta, deltaBus);
		conv3.map(\theta, thetaBus);
	});
};

// do things in the right order
Routine.run({
	( // allocate three buffers
		b = Buffer.alloc(s,4096);
		c = Buffer.alloc(s,4096);
		d = Buffer.alloc(s,4096);
		b.zero;
		c.zero;
		d.zero;
	);
	0.5.wait;
	// do stuff
	loadBuffs.value(buffArray); // load buffers

	// make the kernals
	0.5.wait;
	kernalArray = Array.fill(buffArray.size, {arg i;
		0.2.wait;  // absolutley necessary!!
		makeKernalArray.value(buffArray[i], infoArray[i][2]);
	});

	// unforunate hack...
	kernalArray[5].do({arg val, i;
		0.0001.wait;
		b.set(i, val);
	});
	kernalArray[4].do({arg val, i;
		0.0001.wait;
		d.set(i, val);
	});
	kernalArray[2].do({arg val, i;
		0.0001.wait;
		c.set(i, val);
	});
	\done.postln;

	// wait a sec to free, then free, otherwise things go wrong
	1.0.wait;
	if(plotKernals, {
		kernalArray.size.do({arg i;
			{kernalArray[i].plot}.defer;
			'inArray: '.post; kernalArray[i].postln;
		});
		}, {}
	);
	freeBuffs.value(buffArray); "buffers freed!!".postln;

	// wait again, then do everything
	0.1.wait;
	runMain.value;
});

)

this.clearAll;