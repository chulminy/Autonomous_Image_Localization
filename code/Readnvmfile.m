function [ImgStruct,PointInfo] = Readnvmfile(folderInImg, nvmFile)
%     - input : nvmfile
%     - ouput : ImgStruct
%               PointInfo  

%{
DataImg structure ---------------------------------------------------------

DataImg.ImgStruct   nImg-by-1 cell 
    imgFile         % image file names (1 char)
    imgSize         % image size (1-by-2 vector)
    f               % focal length (1 scalar)
    R               % rotation matrix (3-by-3 matrix)
    C               % translation vector (1-by-3 vector) 
    P               % projective matrix (3-by-4 matrix)
    K               % camera calibration matrix (3-by-3 matrix)
    rDist           % radial distortion (1 scalar)
Please refer to Chapter 6 in "Multiple view geometry" by Hartley    
            
DataImg.PointInfo   nPt3D-by-1 cell
    pt3D            % 3D location  (1-by-3 vector)
    ptRGB           % RGB values
    nMatch          % the number images which are corresponded to 
                      compute the 3D point
    matchImg        % list of images (nMatch-by-1 vector). 
    siftIdx         % sift feature index in each image
%}

% read a nvmfile
nvm     = fileread(nvmFile);
nImg    = textscan(nvm, ' %f  ','HeaderLines',2);  % skip first two lines 
nImg    = nImg{1}(1);   % # of tested images

% read camera matrix
cam     = textscan(nvm, ' %q %f  %f  %f  %f  %f %f  %f  %f  %f  %f',...
             nImg, 'HeaderLines',3);                                  

imgFileName       = cam{1};
fMat              = cam{2};
quaternionMat     = cell2mat(cam(3:6));
RMat              = Quaternion2ROT(quaternionMat);
CMat              = cell2mat(cam(7:9));
rDistMat          = cam{10};

ImgStruct(nImg)   = struct();
for ii=1: nImg
    [~,filename, ext] = fileparts(imgFileName{ii});
    info = imfinfo(fullfile(folderInImg, imgFileName{ii}));

    ImgStruct(ii).imgFile = [filename ext];
    ImgStruct(ii).imgSize = [info.Width info.Height];
    ImgStruct(ii).f = fMat(ii);
    ImgStruct(ii).R = reshape(RMat(ii,:),3,3);
    ImgStruct(ii).C = CMat(ii,:);
    ImgStruct(ii).K = ...
                [fMat(ii) 0 info.Width/2;0 fMat(ii) info.Height/2; 0 0 1];
    ImgStruct(ii).P = ImgStruct(ii).K * ...
        [ImgStruct(ii).R  -1*ImgStruct(ii).R*ImgStruct(ii).C'];
    ImgStruct(ii).rDist = rDistMat(ii);
end

%--------------------------------------------------------------------------
nPt3D = textscan(nvm, ' %f  ',1,'HeaderLines',4+nImg); 
nPt3D = nPt3D{1};                        

points   = textscan(nvm, '%f ','HeaderLines',5+nImg);
points   = cell2mat(points);              

PointInfo(nPt3D)  = struct();

idx = 1;
for ii=1:nPt3D
    PointInfo(ii).Pt3D      = points(idx:idx+2)';
    PointInfo(ii).PtRGB     = points(idx+3:idx+5)';
    
    nMatch = points(idx+6);
    PointInfo(ii).nMatch    = nMatch;

    tmpImg  = zeros(nMatch,1);
    tmpSift = zeros(nMatch,1);
    for jj=1: nMatch
        tmpImg(jj)   = points(idx+7+(jj-1)*4);
        tmpSift(jj)  = points(idx+7+(jj-1)*4+1);
    end
    PointInfo(ii).matchImg       = tmpImg+1;
    PointInfo(ii).siftIdx        = tmpSift+1;
    
    idx = idx + 7 + nMatch*4; 
end

end

function ROT = Quaternion2ROT(qmat)

ROT = zeros(size(qmat,1),9);
for ii=1:size(qmat,1)
    q = qmat(ii,:);
    q = q./norm(q);
    rotmat = [ 1 - 2*q(3).^2 - 2*q(4).^2,  ...
        2*q(2)*q(3) - 2*q(1)*q(4), ...
        2*q(4)*q(2) + 2*q(1)*q(3); ...
        ...
        2*q(2)*q(3) + 2*q(1)*q(4), ...
        1 - 2*q(2).^2 - 2*q(4).^2, ...
        2*q(3)*q(4) - 2*q(1)*q(2); ...
        ...
        2*q(4)*q(2) - 2*q(1)*q(3), ...
        2*q(3)*q(4) + 2*q(1)*q(2), ...
        1 - 2*q(2).^2 - 2*q(3).^2 ];
    ROT(ii,:) = rotmat(:);
end
end