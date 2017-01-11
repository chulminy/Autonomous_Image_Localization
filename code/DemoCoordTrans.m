%% Coordinate Transformation
%
% This code is to find M (7-parameter transformation matrix) by
% corresponding reference points, preliminarily defined by a user using a
% 3D drawing or manual maeasurement, to the 3D points registered in SfM
% models. To register 3D points in SfM models, the user manually coorespond
% same points on multiple images. In this study, 12 reference points are
% defined in advance. This means you need to register 12 points in the SfM
% model. Some sfm softwares deployed an interactive interface in 3D sfM
% model to make it easy to this process. However, personally, working in 3D
% is very laggy and asking you special skill (?). This tool support you to
% relatively easy and fast to register these points.
%
% First, you will add images that include a specific reference point to the
% corresponding folder in "out-refer". 3~6 images are enough. I drawed
% small cicular dots on the truss and those are our reference points. Since
% the images were consecutively captured, you can easily put those images
% in a certain folder. See the images in the folders of "out-refer-1~12'.
% Then, run this code. Note that YOU ARE GOING TO USE UNDISTORTED IMAGES
% !!! not original input images. However, It doesn't matter whether you add
% original images or undistorted images in the folders in "refer". Images
% are automatically loaded from folderOutImgUndist.
%
% I used 12 reference points for this study but theoretically, you need to
% have more three points for cooridnate transformationif they are not
% collinear. To register 3D points in SfM, I uses several images for
% increasing the accuracy. Theoretically, you just use more than 2 images.
%
% This code help the user to easily register these points. Please
% watch this video if you have no idea:
%
%
%% Initialization ---------------------------------------------------------
Parameters;

for pp=1:64;fprintf('-');end; fprintf('\n');
disp('Initialize parameters');
for pp=1:64;fprintf('-');end; fprintf('\n');

% register all reference points on images that you added in the folder of
% "refer"
doPointRegistration = false;

% Compute M matrix for cooridnate transformation. You should first complete
% point registration
doCoordinateTransformation = true;

if doPointRegistration
    %% Step 1: Selection of a points of a reference point on image
    for pp=1:64;fprintf('-');end; fprintf('\n');
    nodeNum = input('Which reference point you are goint to register?');
    for pp=1:64;fprintf('-');end; fprintf('\n');
    
    foderRefer      = fullfile(folderIn,'refer');
    folderReferImg  = fullfile(foderRefer, int2str(nodeNum));
    
    if ~exist(fullfile(foderRefer, ...
            ['refImgPt' int2str(nodeNum) '.mat']),'file')
        %% Read images in a folder of "refer"
        load(fullfile(folderOutData,'ImgStruct.mat'),'ImgStruct');
        
        imgFile = {ImgStruct(:).imgFile};
        
        imgList         = dir(fullfile(folderReferImg,'*.jpg'));
        
        % some images are not used for constructing the SfM model
        imgRefer.imgIdx     = find(ismember(imgFile, {imgList(:).name}));
        imgRefer.nImg       = numel(imgRefer.imgIdx);
        
        %% Step 2: select a point in each images
        nTest   = imgRefer.nImg;
        u       = zeros(2,nTest);
        for ii=1:nTest
            imgIdx  = imgRefer.imgIdx(ii);
            
            img     = imread(...
                fullfile(folderOutImgUndist,ImgStruct(imgIdx).imgFile));
            
            disp('Please hold a Shift key and select only one point');
            
            [u1,v1] = getline_zoom(img,'plot');
            
            u(:,ii) = [u1;v1];
            
            if numel(u1)>1; error('Please select only one point'); end;
        end
        save(fullfile(foderRefer, ...
            ['refImgPt' int2str(nodeNum) '.mat']), 'u','imgRefer');
    else
        fprintf(['You already complete the point registration'  ...
            'on the node %d \n'], nodeNum);
    end
end

if doCoordinateTransformation
    
    load(fullfile(folderOutData,'ImgStruct.mat'),'ImgStruct');
    load(refPointFile,'locReferPt');

    XT = locReferPt;
    
    % check if you complete the point registration
    nReferPt        = size(XT,1);
    for nodeNum=1:nReferPt
        if ~exist(fullfile(foderRefer, ...
                ['refImgPt' int2str(nodeNum) '.mat']),'file')
            error('You need to finish the point registration process');
        end
    end
    
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
    
    % 7 parameter transformation
    [regParams,~,~]=absor(XS',XT','doScale',1);
    
    M = regParams.M;
    
    save(fullfile(folderOutData,'DataM.mat'),'M');
end