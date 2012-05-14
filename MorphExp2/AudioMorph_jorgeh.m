function final=AudioMorph_jorgeh(sound1,sound2,sr,lambdaList)if nargin < 3	sr = 22050;endif nargin < 4	lambdaList=[0:0.25:1];endspecLength = 512;% added by jorgeh, to use YIN instead of the missin rabpitch() function% for pitch estimationframeIncrement = 64; % should I change yin_params.minf0 = 100;yin_params.maxf0 = 300;yin_params.hop = frameIncrement;yin_params.bufsize = 512; % need to be more than sr/minf0yin_params.sr = sr;yin_params.wsize = 256; % jorgeh: not sure about this one	disp('Computing pitch, mfcc, and spectrogram of signal 1.');	%sound1pitch = pitchsnake(sound1,sr,sr/64,100,300);    yin_s1=yin(sound1,yin_params);    sound1pitch  = 440*(2.^(yin_s1.f0));	sound1mfcc = mfcc2(sound1, sr, sr/frameIncrement);	sound1spect = ppspect(sound1, specLength);	disp('Computing pitch, mfcc, and spectrogram of signal 2.');	%sound2pitch = pitchsnake(sound2,sr, sr/64, 100, 300);	yin_s2=yin(sound2,yin_params);    sound2pitch  = 440*(2.^(yin_s2.f0));	sound2mfcc = mfcc2(sound2, sr, sr/frameIncrement);	sound2spect = ppspect(sound2, specLength);	sound1width = min([length(sound1pitch), ...						size(sound1mfcc,2), ...						size(sound1spect,2)]);	sound1pitch = sound1pitch(1:sound1width);	sound1mfcc = sound1mfcc(:, 1:sound1width);	sound1spect = sound1spect(:, 1:sound1width);		sound2width = min([length(sound2pitch), ...						size(sound2mfcc,2), ...						size(sound2spect,2)]);	sound2pitch = sound2pitch(1:sound2width);	sound2mfcc = sound2mfcc(:, 1:sound2width);	sound2spect = sound2spect(:, 1:sound2width);	disp('Computing the dynamic time warping.');	[error,path1,path2] = dtw(sound1mfcc, sound2mfcc);	clear sound1mfcc	clear sound2mfcc% Now (optionally) plot the result.  if 1	m = max(size(sound1spect,2), size(sound2spect,2));	d1 = specLength/2+1;		subplot(3,1,1);		imagesc(sound1spect);		axis([1 m 1 d1]);	title('Signal 1');	s15 = zeros(size(sound1spect));	for i=1:size(sound1spect,2)		s15(:,i) = sound2spect(:,path1(i));	end	subplot(3,1,2);		imagesc(s15);		axis([1 m 1 d1]);	title('Signal 2 warped to be like Signal 1');	clear s15		subplot(3,1,3);		imagesc(sound2spect);		axis([1 m 1 d1]);	title('Signal 2');endwhos;% OK, now we have the two spectrograms: sound1spect and sound2spect% We have warping paths: path1 and path2% We have pitch values: sound1pitch and sound2pitchspecLength = size(sound2spect,1);f=(1:specLength)'-1;f0 = flipud(sound1spect);f1 = flipud(sound2spect);final=[];for lambda=lambdaList	[index1,index2]=TimeWarpPaths(path1,path2,lambda);	specLength = length(index1);	image = zeros(size(sound2spect,1),specLength);	alpha = sound2pitch(index2)./sound1pitch(index1);		for i=1:specLength		i0=round(f/(1 + lambda*(alpha(i) - 1))) + 1;		i0=max(1,min(specLength,i0));		i1=alpha(i)*(i0-1) + 1;		i1=max(1,min(specLength,i1));		image(:,i) = lambda*f1(i1,index2(i)) + (1-lambda)*f0(i0,index1(i));	end	image=flipud(image);	if nargout < 1		filename = sprintf('image%g.raw',lambda);		fopen(filename,'wb');		.........	end	final=[final image];end		