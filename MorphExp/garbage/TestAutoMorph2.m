% Just like TestAutoMorph, except this code interpolates the pitch and
% smooth spectrogram separately.
lambdaList=[0:.33333:1];

% Read in the sounds.
if exist('morning') ~= 1
	mc = ReadSound('MorningCorner.aiff');
	morning = mc(1:16300);
	corner = mc(15000:length(mc));
	clear mc;
	sr=22050;
end

% Calculate both pitch signals
if exist('morningpitch') ~= 1
	disp('Calculating pitch of corner....');
	cornerpitch=pitchsnake(corner,sr,sr/64,100,300);
	cornerwidth = length(cornerpitch);
	disp('Calculating pitch of morning....');
	morningpitch=pitchsnake(morning,sr,sr/64,100,300);
	morningwidth = length(morningpitch);
end

if exist('morningPitchSpect') ~= 1
	disp('Calculating mfcc of morning....');
	[morningMfcc,morningSpect,morningFb, morningFbrecon, morningSmooth] = ...
			mfcc2(morning, sr, sr/64);
	morningMfcc = morningMfcc(:,1:morningwidth);
	morningSmooth = morningSmooth(:,1:morningwidth);
	morningSpect = abs(morningSpect(:,1:morningwidth));
	morningPitchSpect = morningSpect ./ morningSmooth;
	clear morningFb
	clear morningFbrecon
%	clear morningSpect
end
	
if 0
	imagesc(morningPitchSpect(1:50,:));hold on
	plot(((morningpitch'/(sr/(size(morningSpect,1)*2))) * (1:8)) + 1);
	title('morningPitchSpect vs morningpitch'); hold off; drawnow;
end

if exist('cornerPitchSpect') ~= 1
	disp('Calculating mfcc of corner....');
	[cornerMfcc,cornerSpect,cornerFb, cornerFbrecon, cornerSmooth] = ...
			mfcc2(corner, sr, sr/64);
	cornerMfcc = cornerMfcc(:,1:cornerwidth);
	cornerSmooth = cornerSmooth(:,1:cornerwidth);
	cornerSpect = abs(cornerSpect(:,1:cornerwidth));
	cornerPitchSpect = cornerSpect ./ cornerSmooth;
	clear cornerFb
	clear cornerFbrecon
%	clear cornerSpect
end

if 0
	imagesc(cornerPitchSpect(1:50,:));hold on
	plot(((cornerpitch'/(sr/(size(cornerSpect,1)*2))) * (1:8)) + 1);
	title('cornerPitchSpect vs cornerpitch'); hold off; drawnow
end

if exist('path1') ~= 1
	disp('Calculating dynamic time warping between MFCCs');
	[error,path1,path2] = dtw(morningMfcc, cornerMfcc);
end


% Now (optionally) plot the result.  
if 0
	m = max(size(morningSmooth,2), size(cornerSmooth,2));
	d1 = 257;
	
	subplot(3,1,1);
		imagesc(morningSmooth);
		axis([1 m 1 d1]);
	title('Signal 1');

	s15 = zeros(size(morningSmooth));
	for i=1:size(morningSmooth,2)
		s15(:,i) = cornerSmooth(:,path1(i));
	end
	subplot(3,1,2);
		imagesc(s15);
		axis([1 m 1 d1]);
	title('Signal 2 warped to be like Signal 1');
	
	subplot(3,1,3);
		imagesc(cornerSmooth);
		axis([1 m 1 d1]);
	title('Signal 2');
end

% OK, now we have the two pitch spectrograms: morningPitchSpect and cornerPitchSpect
% We have two smooth spectrograms: morningSmooth, cornerSmooth
% We have warping paths: path1 and path2
% We have pitch values: morningpitch and cornerpitch
disp('Do the final morph...');
specLength = size(cornerSmooth,1);
f=(1:specLength)'-1;
final=[];
for lambda=lambdaList
	[index1,index2]=TimeWarpPaths(path1,path2,lambda);
	specWidth = length(index1);
	image = zeros(size(cornerSmooth,1),specWidth);
	alpha = cornerpitch(index2)./morningpitch(index1);
	
	for i=1:specWidth
										% First scale the pitch spectrograms
										% by their difference in pitch
										% See page 101 of Malcolm's first log
										% book for derivation of the following.
		i0=round(f/(1 + lambda*(alpha(i) - 1))) + 1;
		i0=max(1,min(specLength,i0));
		i1=round(alpha(i)*f/(1 + lambda*(alpha(i) - 1))) + 1;
		i1=max(1,min(specLength,i1));
		newPitchSpec = lambda*cornerPitchSpect(i1,index2(i)) + ...
					(1-lambda)*morningPitchSpect(i0,index1(i));
		
		if 1
			morningWarp(:,i) = morningPitchSpect(i0,index1(i));
			cornerWarp(:,i) = cornerPitchSpect(i1,index2(i));
			lambdaWarp(:,i) = newPitchSpec;
		end
										% Now interpolate the smooth 
										% spectrum.
		if 0
			newSmoothSpec = TukeyMorph(morningSmooth(:,index1(i)), ...
									cornerSmooth(:,index2(i)), lambda);
		elseif 0						% Tukey morph on untilted spectrums
			mt = SpectralTilt(morningSmooth(:,index1(i)),-1);
			ct = SpectralTilt(cornerSmooth(:,index2(i)),-1);
			newSmoothSpec = TukeyMorph(mt, ct, lambda);
			newSmoothSpec = SpectralTilt(newSmoothSpec,1);
		else
			newSmoothSpec = Interpolate(morningSmooth(:,index1(i)), ...
									cornerSmooth(:,index2(i)), lambda);
		end
			
		if 1
			lambdaSmooth(:,i) = newSmoothSpec;
		end
		
		image(:,i) = newPitchSpec .* newSmoothSpec;
	end
	final=[final image];
end		

if 1
	morph = SpectrumInversion(SpectralTilt(final,-1),64,256);
end

if 0
									% Plot original and morphed spectrograms
	subplot(3,1,1);imagesc(morningSpect);title('morningSpect');
	subplot(3,1,2);imagesc(image);title('50% Morph');
	subplot(3,1,3);imagesc(cornerSpect);title('cornerSpect');

									% Plot pitch and morphed spectrograms
	subplot(3,1,1);imagesc(SpectralTilt(morningPitchSpect,-1));title('morningPitchSpectrum');
	subplot(3,1,2);imagesc(image);title('50% Morph');
	subplot(3,1,3);imagesc(SpectralTilt(cornerPitchSpect,-1));title('cornerPitchSpectrum');
	
									% Plot spectral slices
	frame=128;
	subplot(3,1,2);plot(image(:,frame));
	subplot(3,1,1);plot(morningPitchSpect(:,index1(frame)));
	subplot(3,1,3);plot(cornerPitchSpect(:,index2(frame)));
	
									% Plot spectral slices (overlayed)
	clg;plot([morningPitchSpect(:,index1(frame)) image(:,frame) ...
				cornerPitchSpect(:,index2(frame))])
	axis([0 50 0 4])

									% Plot pitch warps
	subplot(3,1,1);imagesc(morningWarp);title('Morning Pitch Warp');
	subplot(3,1,2);imagesc(lambdaWarp);title('50% Morph');
	subplot(3,1,3);imagesc(cornerWarp);title('Corner Pitch Warp');

									% Plot pitch warps (overlayed)
	frame = 80;
	clg;plot([morningWarp(:,frame) lambdaWarp(:,frame) ...
				cornerWarp(:,frame)])
	axis([0 50 0 4])
	
end

if 0
									% Check the inversion back to sound.
	ymorning = SpectrumInversion( ...
			SpectralTilt(morningPitchSpect.*morningSmooth,-1),64,256);
	y = SpectrumInversion(SpectralTilt(image,-1),64,256);
	ycorner = SpectrumInversion( ...
			SpectralTilt(cornerPitchSpect.*cornerSmooth,-1),64,256);
end

if 0
	morningTrue = abs(ComplexSpectrum(morning,64,256));
	cornerTrue = abs(ComplexSpectrum(corner,64,256));
	
	ymorningtrue = SpectrumInversion(morningTrue,64,256);
	sound(ymorningtrue,22050);
	ycornertrue = SpectrumInversion(cornerTrue,64,256);
	sound(ycornertrue,22050);
	
	subplot(2,1,1);plot(morning);title('morning');
	subplot(2,1,2);plot(-ymorningtrue);title('morning reconstruction');
	while 1
		start = input('Starting sample? ');
		subplot(2,1,1); axis([start start+1000 -.2 .2]);
		subplot(2,1,2); axis([start start+1000 -.2 .2]);
	end		
									% Hmmm, problems with inversion
									% of morning around sample 2400.
	ymorningtrue1 = SpectrumInversion(morningTrue,64,256,1);
end

if 0
									% Check to make sure that I can
									% successfully invert the MFCC
									% spectrograms.
	[morningMfcc,morningSpect,morningFb, morningFbrecon, morningSmooth] = ...
			mfcc2(morning, sr, sr/64);
	morningMfcc = morningMfcc(:,1:morningwidth);
	morningSmooth = morningSmooth(:,1:morningwidth);
	morningSpect = abs(morningSpect(:,1:morningwidth));
	morningPitchSpect = morningSpect ./ morningSmooth;
	clear morningFb
	clear morningFbrecon
	
	ymorning = SpectrumInversion(SpectralTilt( ...
				morningPitchSpect.*morningSmooth,-1),64,256);
end

if 0
	subplot(3,2,1);
	imagesc(morningSmooth);title('morningSmooth');
	
	subplot(3,2,2);
	imagesc(morningPitchSpect);title('morningPitchSpect');
	
	subplot(3,2,3);
	imagesc(lambdaSmooth(:,1:size(image,2))); title('lambdaSmooth');
	
	subplot(3,2,4);
	imagesc(lambdaWarp(:,1:size(image,2))); title('lambdaWarp');
	
	subplot(3,2,5);
	imagesc(cornerSmooth);title('cornerSmooth');
	
	subplot(3,2,6);
	imagesc(cornerPitchSpect);title('cornerPitchSpect');
end
