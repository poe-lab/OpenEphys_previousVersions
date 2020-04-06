function OpenEphysContinuousToNCS_Filtered_08022018
ADchannel{1,1} = 7;

%% Select an Open Ephys spike file:
[continFilename, continFilePath] = uigetfile({'*.continuous',...
        'Pick Open Ephys continuous file'},'Select CSC File');
continFile = fullfile(continFilePath, continFilename);
settingsFile = fullfile(continFilePath, 'settings.xml');
ncsFile = strrep(continFile, '.continuous', '.ncs'); %Create the .NCS file name
clear continFilePath continFilename
tic
%% Load data from the Open Ephys CSC file:
[data, timestamps, info] = load_open_ephys_data(continFile);
% data is in microvolts
% time stamps are in seconds
clear continFile

%% Invert waveform since it is not inverted at the time of the recording:
data = -1 * data;

%% Filter the data:
lowCutFreq = 0.1; % Highpass filter
HighCutFreq = 300; % Lowpass filter
[z, p, k] = ellip(7,1,60, [lowCutFreq HighCutFreq]/(info.header.sampleRate/2),'bandpass');
[sos, g] = zp2sos(z,p,k);
data = filtfilt(sos,g, data);
clear z p k sos g

%% Down sample the data and time stamps to 1000 samples/second:
if info.header.sampleRate < 2000
    downsampleFreq = info.header.sampleRate;
else
    downsampleFreq = 1000;
    downsampleRate = floor(info.header.sampleRate/downsampleFreq);
    data = data(1:downsampleRate:end);
    timestamps = timestamps(1:downsampleRate:end);
end 

m2= length(data);
newEnd = floor(m2/512);
shortEnd = newEnd * 512;
data = data(1:shortEnd);
timestamps = timestamps(1:shortEnd);

%% Load channel map from OE settings file:
% Initialize variables.
delimiter = '';
startRow = 6;

% Format for each line of text:
formatSpec = '%q%[^\n\r]'; % Read in strings for each line in file.

% Open the text file.
fileID = fopen(settingsFile,'r');

% Read columns of data according to the format.
textscan(fileID, '%[^\n\r]', startRow-1, 'WhiteSpace', '', 'ReturnOnError', false, 'EndOfLine', '\r\n');
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'MultipleDelimsAsOne', true, 'ReturnOnError', false);

% Close the text file.
fclose(fileID);

% Allocate imported array to column variable names
settings = dataArray{:, 1};

% Clear temporary variables
clearvars settingsFile delimiter startRow formatSpec fileID dataArray ans;

% % Find AD channel number:
% x = strmatch(['<CHANNEL name="' info.header.channel '" number='], settings);
% channelStr = settings{x};
% clear settings x
% channelStr = replace(channelStr,['<CHANNEL name="' info.header.channel '" number='],'');
% ADchannel = textscan(channelStr,'%f %*[^\n]'); %AD channel number starting at Ch 0
% clear channelStr

%% Get the variables Neuralynx NCS Header:

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

chNum = strrep(info.header.channel, 'CH', ''); %CSC channel number

%% Create the Neuralynx NCS Header:
% To solve for ADBitVolts in Neuralynx:
%   ADBitVolts = (Max Volts)/ADMAxValue
%   Open Ephys max voltage = 12.78 mV = 0.01278 V
%   Neuralynx AD Max Value = 32767 (Cheetah v5, 32-bit Digital Lynx system)
%       !!! This may need to change if we ever have to put into 64-bit
%       version!!!
%   Neuralynx ADBitVolts = 0.01278/32767 = 3.900265511032441e-07

ncsHeader = {'######## Neuralynx Data File Header ';
    ['## File Name ' ncsFile];
    ['## Time Opened (m/d/y): ' openDate '  (h:m:s.ms) ' openTime];
    ['## Time Closed (m/d/y): ' closeDate '  (h:m:s.ms) ' closeTime];
    '-FileType CSC';
    '-FileVersion 3.3.0';
    '-RecordSize 1044';
    '-CheetahRev 5.6.3 ';
    '-HardwareSubSystemName AcqSystem1';
    '-HardwareSubSystemType DigitalLynx';
    ['-SamplingFrequency ' num2str(downsampleFreq)];
    '-ADMaxValue 32767'; % This may be system dependent--see above.
    '-ADBitVolts 3.900265511032441e-07';
    ['-AcqEntName CSC' chNum]; %Shift CSC # by +1 for Neuralynx
    '-NumADChannels 1'; % This is a single channel of continuous data.
    ['-ADChannel ' num2str(ADchannel{1,1})];
    '-InputRange 12780'; % in microvolts
    '-InputInverted True'; % We inverted the data after imported from OE file.
    '-DSPLowCutFilterEnabled True'; 
    ['-DspLowCutFrequency ' num2str(lowCutFreq)];
    '-DspLowCutNumTaps 0'; %!!!Not sure about this
    '-DspLowCutFilterType DCO';
    '-DSPHighCutFilterEnabled True';
    ['-DspHighCutFrequency ' num2str(HighCutFreq)]; 
    '-DspHighCutNumTaps 256'; %!!!Not sure about this
    '-DspHighCutFilterType FIR';
    '-DspDelayCompensation Disabled'; %Keep disabled since there is no delay filtering offline using 'filtfilt'
    '-DspFilterDelay_µs 0';
    };

%% Reshape data into Neuralynx format:
data = reshape(data, 512, newEnd);

%% Convert data from microvolts to AD Value:
data = data/(3.900265511032441e-07 * 1000000);

%% Reshape time stamps:
timestamps = timestamps(1:512:end);

%% Convert time stamps from seconds to microseconds:
timestamps = timestamps*1000000;

SampleFrequencies = downsampleFreq * ones(1, newEnd);
NumberOfValidSamples = 512 * ones(1, newEnd);
Mat2NlxCSC(ncsFile, 0, 1, 1, [1 1 1 1 1 1], timestamps', info.recNum(1:newEnd), SampleFrequencies, NumberOfValidSamples, data, ncsHeader);
clear timestamps info SampleFrequencies NumberOfValidSamples data ncsHeader
toc
end