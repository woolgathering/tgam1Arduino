(
var textfile, sigArray, path, sig, mean, testWave;

// open data file and put it in an array
path = thisProcess.nowExecutingPath.dirname +/+ "rawEEG/two.txt";
textfile = FileReader.read(path, true, true, delimiter: '\n');
textfile.size.postln;

sigArray = Array.fill(textfile.size, {arg i;
	textfile[i][0];
});
sigArray = sigArray.asFloat;


// center and normalize
mean = {
	var sum = 0;
	sigArray.do({arg val;
		sum = sum + val;
	});
	sum/(sigArray.size);
};
sig = Signal.fill(sigArray.size, {arg i;
	sigArray[i];
});
sig = (sig - mean.value).normalize;
// sig.postln;

// make me a wave file!!!
testWave = SoundFile.new.headerFormat_("WAV").sampleFormat_("int32").numChannels_(1).sampleRate_(128);
testWave.openWrite(thisProcess.nowExecutingPath.dirname +/+ "rawEEG/two.wav");
testWave.writeData(sig);
testWave.close;

10.do({arg i;
	sig[i].postln;
});


)