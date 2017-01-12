% All plotted images will be saved in folderOutcome.

DemoCode;

folderOutcome   = fullfile(folderOut,'outcome');
folderHome      = fullfile(folderOutcome,'homepage');

%% Show a sample of input raw images
imgSize = round(ImgStruct(1).imgSize*0.2);
imageset = zeros(imgSize(2),imgSize(1),3,15,'uint8');
prm = struct('mm',3,'nn',5,'padAmt',1,'hasChn',1,'showLines',1);
idx = randperm(numel(ImgStruct),15);
for ii=1:15
    imageset(:,:,:,ii) = imresize(imread(fullfile( ...
        folderOutImgUndist,ImgStruct(idx(ii)).imgFile)),0.2);
end
figure('Name','PlotOut1'); clf; h = montage2(imageset, prm );
imwrite(h.CData,fullfile(folderOutcome,'PlotOut1.jpg'));
imwrite(imresize(h.CData,[NaN 900]), ...
    fullfile(folderHome,'PlotOut1.jpg'));
clearvars imageset imgSize nTrImg prm

%% Evaluation of transformation matrix M
load(refPointFile,'locReferPt');
load(fullfile(folderOutData,'DataM.mat'));

% XT and XS  are any corresponding 3D points (a 4-dimensional vector)
% defined in TRI and SfM coordinates, respectively.
XT = locReferPt;

nReferPt = size(locReferPt,1);

XS = zeros(nReferPt,3);
% estimation of 3D point from points on image matches
for nodeNum=1:nReferPt
    load(fullfile(foderRefer,['refImgPt' int2str(nodeNum) '.mat']));
    nTest   = imgRefer.nImg;
    P       = cell(nTest,1);
    imSize  = zeros(2,nTest);
    for ii=1:nTest
        imgIdx  = imgRefer.imgIdx(ii);
        P{ii}   = ImgStruct(imgIdx).P;
        % Attention! the order is different in
        % "vgg_X_from_xP_nonline.m"
        imSize(:,ii)  = flipud(ImgStruct(imgIdx).imgSize');
    end
    X  = vgg_X_from_xP_nonlin(u,P,imSize);
    
    XS(nodeNum,:) = transpose(X(1:3))./X(4);
end

h = figure('Name','PlotOut2'); 
plot3(XT(:,1),XT(:,2),XT(:,3),'ob','markerSize',8,'linewidth',2); hold on; 
transPt = M* cat(1,XS',ones(1,nReferPt));
transPt = bsxfun(@rdivide,transPt(1:3,:),transPt(4,:))'
plot3(transPt(:,1),transPt(:,2),transPt(:,3),'xr');
legend('\bf Reference points (X^T) in TRI', ...
'\bf M*X^S (transformed points)','location','northwest');
xlabel('X-axis');ylabel('Y-axis');zlabel('Z-axis');
grid on; axis equal;
set(gca,'fontsize',12,'linewidth',2,'fontweight','bold')
set(h,'PaperPositionMode','auto','pos',[50 50 900 450])
print(fullfile(folderHome,'PlotOut2'),'-djpeg','-r0'); hold off;
print(fullfile(folderOutcome,'PlotOut2'),'-djpeg','-r0'); hold off;

%% Reprojection of the reference points to the images
nodeNum = 3;
load(fullfile(foderRefer,['refImgPt' int2str(nodeNum) '.mat']));
load(refPointFile,'locReferPt');
nTest   = imgRefer.nImg;
P       = cell(nTest,1);
imSize  = zeros(2,nTest);
for ii=1:nTest
    imgIdx  = imgRefer.imgIdx(ii);
    P{ii}   = ImgStruct(imgIdx).P;
    % Attention! the order is different in
    % "vgg_X_from_xP_nonline.m"
    imSize(:,ii)  = flipud(ImgStruct(imgIdx).imgSize');
end
XS  = vgg_X_from_xP_nonlin(u,P,imSize);

nTest   = imgRefer.nImg;

ptIdx   = 1; % plot first point
imgIdx  = imgRefer.imgIdx(ptIdx);
P       = ImgStruct(imgIdx).P;
img     = imread(...
    fullfile(folderOutImgUndist,ImgStruct(imgIdx).imgFile));

img = ...
    insertShape(img,'circle',[u(:,ptIdx)' 6],'lineWidth', 2,'color','red');

ptA         = P*XS;
ptA         = ptA(1:2)/ptA(3);
img = insertShape(img,'circle',[ptA' 6],'lineWidth', 2,'color', 'green');

ptB         = P*inv(M)*[locReferPt(nodeNum,:)';1];
ptB         = ptB(1:2)/ptB(3);
img         = ...
    insertShape(img,'circle',[ptB' 6],'lineWidth', 2,'color', 'black');

figure('Name','PlotOut3a'); imshow(img);
cropImg = imcrop(img,[ptA'-[100 100], 200,200]);
figure('Name','PlotOut3a'); imshow(cropImg);

imwrite(img, fullfile(folderOutcome,'PlotOut3a.jpg'));
imwrite(cropImg, fullfile(folderOutcome,'PlotOut3b.jpg'));

imwrite(imresize(img,[NaN 900]), fullfile(folderHome,'PlotOut3a.jpg'));
imwrite(imresize(cropImg,[NaN 900]), fullfile(folderHome,'PlotOut3b.jpg'));

%% Extract ROI from the original images
nImg = numel(ImgStruct);

folderOutImgWeld = fullfile(folderOutcome,'weld');
if ~exist(folderOutImgWeld,'dir'); mkdir(folderOutImgWeld); end;

folderOutImgWeldFull = fullfile(folderOutcome,'weldFull');
if ~exist(folderOutImgWeldFull,'dir'); mkdir(folderOutImgWeldFull); end;

validWeldMat = [DataWeld(:).validWeld]; % 
for ii=1:nImg
    imgFile = fullfile(folderOutImgUndist,ImgStruct(ii).imgFile);
    [~,name,ext] = fileparts(imgFile);

    img         = imread(imgFile);
    imgAllWeld  = img;
    weldIdx = find(validWeldMat(ii,:));
    for jj=1:numel(weldIdx)
        patchFolder = fullfile(folderOutImgWeld, ...
            sprintf('%05d',weldIdx(jj)));
        if ~exist(patchFolder,'dir')
            mkdir(patchFolder);
        end
        patchFile = fullfile(patchFolder, [name ext]);
        imwrite(imcrop(img,DataWeld(weldIdx(jj)).cropBox(ii,:)),patchFile);

        imgAllWeld = insertShape(imgAllWeld,'rectangle', ...
            DataWeld(weldIdx(jj)).cropBox(ii,:), ...
            'lineWidth', 15,'color', 'red');
    end
    imwrite(imresize(imgAllWeld,[NaN 900]), ...
        fullfile(folderOutImgWeldFull,ImgStruct(ii).imgFile));
end

%% Display weld images
weldID = 34;
folderWeldPatch = fullfile(folderOutImgWeld,sprintf('%05d',weldID));
imageset = zeros(300,300,3,45,'uint8');
prm = struct('mm',5,'nn',9,'padAmt',1,'hasChn',1,'showLines',1);

imgFile = dir(fullfile(folderWeldPatch,'*.jpg'));
for ii=1:45
    imageset(:,:,:,ii) = imresize(imread(fullfile( ...
        folderWeldPatch,imgFile(ii).name)),[300 300]);
end
figure('Name','PlotOut4'); clf; h = montage2(imageset, prm );
imwrite(h.CData, fullfile(folderOutcome,'PlotOut4a.jpg'));
imwrite(imresize(h.CData,[NaN 900]),fullfile(folderHome,'PlotOut4a.jpg'));
clearvars imageset prm

weldID = 2;
folderWeldPatch = fullfile(folderOutImgWeld,sprintf('%05d',weldID));
imageset = zeros(300,300,3,45,'uint8');
prm = struct('mm',5,'nn',9,'padAmt',1,'hasChn',1,'showLines',1);

imgFile = dir(fullfile(folderWeldPatch,'*.jpg'));
for ii=1:45
    imageset(:,:,:,ii) = imresize(imread(fullfile( ...
        folderWeldPatch,imgFile(ii).name)),[300 300]);
end
figure('Name','PlotOut4'); clf; h = montage2(imageset, prm );
imwrite(h.CData, fullfile(folderOutcome,'PlotOut4b.jpg'));
imwrite(imresize(h.CData,[NaN 900]),fullfile(folderHome,'PlotOut4b.jpg'));
clearvars imageset prm