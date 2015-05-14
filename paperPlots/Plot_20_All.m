addpath('../tforms');

%load the data
data = load('../results/Test_24.11_Kitti.mat');

%9_26
% velCam1 = [0.272366992403569,0.000401046031637955,-0.0743065916413621,-1.21456402386260,1.18928496715603,-1.20243957469666];
% velCam2 = [0.277752531522258,-0.536729003952002,-0.0776835216236700,-1.19271705822817,1.22722093116592,-1.20702757977384];
% velCam3 = [0.269025963816496,0.0599294920311864,-0.0745533295124208,-1.21875939088579,1.19261583495551,-1.20811422737780];
% velCam4 = [0.274374681029614,-0.472760662203873,-0.0751478768336082,-1.19212577481800,1.21673693585499,-1.20669925715255];

%10_03
velCam1 = [0.291804720076481,-0.0114055066485929,-0.0562394126383353,-1.21437856632943,1.20575835034676,-1.20140449070730];
velCam2 = [0.292034456780211,-0.548572251398307,-0.0605822662128782,-1.19262401861693,1.24394317283683,-1.20667887644520];
velCam3 = [0.287988792734513,0.0481207596442812,-0.0572301603112048,-1.21927554848229,1.20959078381303,-1.20612910053213];
velCam4 = [0.287103485048149,-0.485304279180288,-0.0584847671355261,-1.19258234104363,1.23385881496779,-1.20595346907977];
% 
% velCam1 = [0.291804720076481,-0.0114055066485929,-0.0562394126383353,-1.21996291041592,1.19352064861705,-1.20328698135780];
% velCam2 = [0.292034456780211,-0.548572251398307,-0.0605822662128782,-1.19838445835617,1.23177493496882,-1.20866875098245];
% velCam3 = [0.287988792734513,0.0481207596442812,-0.0572301603112048,-1.22490083432879,1.19734460203756,-1.20797392149138];
% velCam4 = [0.287103485048149,-0.485304279180288,-0.0584847671355261,-1.19829980383047,1.22168615991537,-1.20794878933315];

gt = [velCam1;velCam2;velCam3;velCam4];

fail = false(50,1);
res = zeros(50,6);
sd = zeros(50,6);
t = zeros(50,2);

r = 1:4;

for i = 1:50
    temp = abs(data.results{i}.final(2:end,:)-gt);
    res(i,:) = mean(temp(r,:),1);
    
    if(any(abs(data.results{i}.final(:))>3))
        fail(i) = true;
    end
    
    t(i,:) = mean(data.results{i}.timeOffset);
    
    temp = zeros(4,3);
    for j = 1:4
        [temp(j,1),temp(j,2),temp(j,3)] = dcm2angle(V2R(data.results{i}.final(j+1,4:6))/V2R(gt(j,4:6)));
    end
    res(i,4:6) = mean(abs(temp(r,:))*180/pi,1);
    
    sd(i,:) = sqrt(mean(data.results{i}.finalVar(2:end,:)));
    temp = zeros(4,3);
    for j = 1:4
        [~,temp(j,:)] = varChange(data.results{i}.final(j+1,4:6),sqrt(data.results{i}.finalVar(j+1,4:6)),gt(j,4:6));
    end
    
    sd(i,4:6) = mean(temp(r,:),1);
end

res = res(~fail,:);
sd = sd(~fail,:);

mean(res)
%% plot

subplot(3,1,1);
errorbar(res(:,1),sd(:,1),'ro')
axis([0,50,0,0.5])
title('X Error');

subplot(3,1,2);
errorbar(res(:,2),sd(:,2),'go')
axis([0,50,0,0.5])
title('Y Error');
ylabel('Calibration Error (m)');

subplot(3,1,3);
errorbar(res(:,3),sd(:,3),'bo')
axis([0,50,0,0.5])
xlabel('Run');
title('Z Error');

figure
subplot(3,1,1);
errorbar(res(:,4),sd(:,4),'ro')
axis([0,50,0,2])
title('Roll Error');

subplot(3,1,2);
errorbar(res(:,5),sd(:,5),'go')
axis([0,50,0,2])
ylabel('Calibration Error (degrees)');
title('Yaw Error');

subplot(3,1,3);
errorbar(res(:,6),sd(:,6),'bo')
axis([0,50,0,2])
xlabel('Run');
title('Pitch Error');