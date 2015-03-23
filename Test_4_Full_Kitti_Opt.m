% this script generates the first set of results in the paper
% It calculates the transformation between the velodyne and camera 0 for drive
% 28 of the kitti data set using the presented method and a simple equal
% weighted least squares method

%% user set variables

%number of scans to use
scansTimeRange = 50;
%scansTimeRange = 5:5:100;

%number of times to perform test
reps = 10;

%samples
timeSamples = 100000;

%% load sensor data
CalibPath(true);
%make sure to read in cameras last (due to issue with how I compensate for scale)
sensorData = LoadSensorData('Kitti','Vel', 'Cam1');

%gives results in terms of positions rather then coordinate frames
%less usful more intuative
sensorData = InvertSensorData(sensorData);

%% fix timestamps
[sensorData, offsets] = CorrectTimestamps(sensorData, timeSamples);

%% run calibration
    
outT = cell(100,1);
outV = cell(100,1);

outTB = cell(100,1);
outVB = cell(100,1);

for w = 1:reps
    tic
    
    %get random contiguous scans to use
    sDataBase = RandTformTimes(sensorData, scansTimeRange);
    
    %evenly sample data
    sData = SampleData2(sDataBase);
    
    %remove uninformative data
    sData = RejectPoints(sData, 10, 0.0001);

    %find rotation
    fprintf('Finding Rotation\n');
    rotVec = RoughR(sData);
    rotVec = OptR(sData, rotVec);
    rotVarL = ErrorEstCR(sData, rotVec,0.01);
    rotVarU = ErrorEstR3(sData, rotVec);
    %[ outVec ] = ErrorEstWR(sData,rotVec);
    %rotVar2 = ErrorEstR(sData, rotVec,100);
    
    %find camera transformation scale (only used for RoughT, OptT does its
    %own smarter/better thing
    fprintf('Finding Camera Scale\n');
    sDataS = EasyScale(sData, rotVec, rotVar,zeros(2,3),ones(2,3));
    
    %clean up large variance
    %sData = ThresholdVar(sData,50);
    
    %show what we are dealing with
    PlotData(sDataS,rotVec);

    %find translation
    %sData = TDiff(sData, rotVec, rotVar);
    
    fprintf('Finding Translation\n');
    tranVec = RoughT(sDataS, rotVec);
    tranVec = OptT(sData, tranVec, rotVec, rotVarU);
    tranVarL = ErrorEstCT(sData, tranVec, rotVec, rotVarU, 0.01);
    tranVarU = ErrorEstT3(sData, tranVec, rotVec, rotVarU);
    
    %tranVar2 = ErrorEstT(sData, tranVec, rotVec, rotVar2, 100);

    %get grid of transforms
    fprintf('Generating transformation grid\n');
    [tGrid, vGrid] = GenTformGrid(tranVec, rotVec, tranVar, rotVar);
    
    %refine transforms using metrics
    fprintf('Refining transformations\n');
    [tGridR, vGridR] = metricRefine(tGrid, vGrid, sDataBase,0.1,10);
    
    %correct for differences in grid
    fprintf('Combining results\n');
    [tVals, vVals] = optGrid(tGridR, vGridR, sensorData);
    
    outT{w} = tVals;
    outV{w} = vVals;
    
    outTB{w} = [tranVec, rotVec];
    outVB{w} = [tranVar, rotVar];
    
    save('Test_45_Res.mat','outT','outV','outTB','outVB');
    toc
    w
end
