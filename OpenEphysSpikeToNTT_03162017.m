function OpenEphysSpikeToNTT_03162017
%% Select an Open Ephys spike file:
[spikeFilename, spikeFilePath] = uigetfile({'*.spikes',...
        'Pick Open Ephys spike file'},'Select Spike File');
spikeFile = fullfile(spikeFilePath, spikeFilename);
nttFile = strrep(spikeFile, '.spikes', '.ntt'); %Create the .NTT file name
clear spikeFilePath spikeFilename

%% Load data from the Open Ephys spike file:
[data, timestamps, info] = load_open_ephys_data(spikeFile);
% data is in microvolts
% time stamps are in seconds
clear spikeFile

%% Get the variables Neuralynx NTT Header:

% extract open date and time:
A = textscan(info.header.date_created,'%s %s');
openDate = datestr(A{1,1}, 23);
timeInSec = str2double(A{1,2})/info.header.sampleRate;
h = floor(timeInSec/3600); %find # of hours since start of recording
timeInSec = mod(timeInSec, 3600);
m = floor(timeInSec/60); %find # of minutes since start of recording
s = mod(timeInSec, 60); %find # of seconds since start of recording
dateVector = [2000, 1, 1, h, m, s];
openTime = datestr(dateVector, 'HH:MM:SS.FFF');
clear A timeInSec h m s dateVector

% extract close date and time:
closeDate = openDate; % !!!Need to change this!!!
timeInSec = ceil(timestamps(end));
h = floor(timeInSec/3600); %find # of hours since start of recording
timeInSec = mod(timeInSec, 3600);
m = floor(timeInSec/60); %find # of minutes since start of recording
s = mod(timeInSec, 60); %find # of seconds since start of recording
dateVector = [2000, 1, 1, h, m, s];
closeTime = datestr(dateVector, 'HH:MM:SS.FFF');
clear timeInSec h m s dateVector

chNum = info.source(1)*4; %AD channel number starting at Ch 0

%% Create the Neuralynx NTT Header:
% To solve for ADBitVolts:
%   (Input Range in microvolts)/(1000000 * ADMAxValue)
%   The 1000000 divisor is to convert from microvolts to volts.


nttHeader = {'######## Neuralynx Data File Header ';
    ['## File Name ' nttFile];
    ['## Time Opened (m/d/y): ' openDate '  (h:m:s.ms) ' openTime];
    ['## Time Closed (m/d/y): ' closeDate '  (h:m:s.ms) ' closeTime];
    '-CheetahRev 5.5.1 ';'';
    ['-AcqEntName TT' num2str(info.source(1) + 1)]; %Shift TT # by +1 for Neuralynx
    '-FileType Spike';
    '-RecordSize 304'; %!!!Not sure about this
    '';'-HardwareSubSystemName AcqSystem1';
    '-HardwareSubSystemType DigitalLynx';
    ['-SamplingFrequency ' num2str(info.header.sampleRate)];
    '-ADMaxValue 32767'; %!!!Not sure about this
    '-ADBitVolts 7.62963e-009 7.62963e-009 7.62963e-009 7.62963e-009 '; %!!!Not sure about this
    '';
    '-NumADChannels 4';
    ['-ADChannel ' num2str(chNum) ' ' num2str(chNum+1) ' ' num2str(chNum+2) ' ' num2str(chNum+3) ' '];
    '-InputRange 250 250 250 250 '; %!!!Not sure about this
    '-InputInverted False';
    '-DSPLowCutFilterEnabled True'; 
    '-DspLowCutFrequency 300'; 
    '-DspLowCutNumTaps 64'; %!!!Not sure about this
    '-DspLowCutFilterType FIR';
    '-DSPHighCutFilterEnabled True'; %!!!Not sure about this
    '-DspHighCutFrequency 3000'; 
    '-DspHighCutNumTaps 32'; %!!!Not sure about this
    '-DspHighCutFilterType FIR';
    '-DspDelayCompensation Disabled'; %!!!Not sure about this
    '-DspFilterDelay_�s 1444'; %!!!Not sure about this
    ['-WaveformLength ' num2str(size(data,2))];
    '-AlignmentPt 8'; %!!!Not sure about this
    ['-ThreshVal ' num2str(info.thresh(1)) ' ' num2str(info.thresh(1)) ' ' num2str(info.thresh(1)) ' ' num2str(info.thresh(1)) ' '];
    '-MinRetriggerSamples 9'; %!!!Not sure about this
    '-SpikeRetriggerTime 250'; %!!!Not sure about this
    '-DualThresholding False';
    '';
    '-Feature Peak 0 0 ';
    '-Feature Peak 1 1 ';
    '-Feature Peak 2 2 ';
    '-Feature Peak 3 3 ';
    '-Feature Valley 4 0 ';
    '-Feature Valley 5 1 ';
    '-Feature Valley 6 2 ';
    '-Feature Valley 7 3 ';};

%% Reshape waveform data:
data = permute(data,[2 3 1]);
data = data(1:32, :, :);

%% Convert data from microvolts to AD Value:
data = data/(7.62963e-009 * 1000000);

%% Convert time stamps from seconds to microseconds:
timestamps = timestamps*1000000;

%% Create Features variable:
X = min(data, [],1);
X = squeeze(X);
Y= max(data,[],1);
Y = squeeze(Y);
Q = [Y;X];
Features = Q;
clear X Y Q

Mat2NlxSpike(nttFile, 0, 1, [], [1 1 1 1 1 1], timestamps',...
    info.source', info.recNum', Features, data, nttHeader);
