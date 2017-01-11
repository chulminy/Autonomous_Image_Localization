%% Initialization ---------------------------------------------------------
Parameters;

for pp=1:64;fprintf('-');end; fprintf('\n');
disp('Initialize parameters');
for pp=1:64;fprintf('-');end; fprintf('\n'); 

%% Read nvmfiles, created trhough visualSFM -------------------------------
if (~exist(fullfile(folderOutData,'ImgStruct.mat'),'file'))
    disp('Generate DataImg for source images');
    for pp=1:64;fprintf('-');end; fprintf('\n'); 
    [ImgStruct,~] = Readnvmfile(folderInImg, nvmFile);
    save(fullfile(folderOutData,'ImgStruct.mat'), 'ImgStruct');
else
    disp('Load DataImg for source');
    for pp=1:64;fprintf('-');end; fprintf('\n'); pause(1);
    load(fullfile(folderOutData,'ImgStruct.mat'));
end
disp('Finish: Reading matching data for source');pause(1);

%% Define common parameters
nImg = numel(ImgStruct);

%% Save undistort images --------------------------------------------------
for ii = 1:nImg
    imgUdist  = fullfile(folderOutImgUndist,ImgStruct(ii).imgFile);
    if ~ exist(imgUdist,'file')
        for pp=1:64;fprintf('-');end; fprintf('\n');
        fprintf('(%d/%d)Transforming undistor image: %s \n',ii,nImg);
        
        I   = imread(fullfile(folderInImg, ImgStruct(ii).imgFile));
        params.cx   = ImgStruct(ii).K(1,3);
        params.cy   = ImgStruct(ii).K(2,3);
        params.r    = ImgStruct(ii).rDist/(ImgStruct(ii).f)^2;
        params.isGPU = isGPU;
        imwrite(Undistort(I,params), imgUdist);
    end
end; clearvars I params imgUdist I params ii;

%% Reference point registration for scaling (MCS) -------------------------
if (~exist(fullfile(folderOutData,'DataM.mat'),'file'))
    error(['Please find M by conducting a coordinate' ...
    'transformation in DemoCoordTrans.m']);
else
    load(fullfile(folderOutData,'DataM.mat'));% load "M"
end
for pp=1:64;fprintf('-');end; fprintf('\n'); pause(1);
disp('Finsih: Reading a transformation matrix from model to source');
for pp=1:64;fprintf('-');end; fprintf('\n'); pause(1);

%% Weld location information
% 118-by-4: 118 weld connections and (x,y,z,weld diameter)
if (~exist(fullfile(folderOutData,'DataWeld.mat'),'file'))
    load(weldLocFile,'weld');
    
    nWeld   = size(weld,1);
    weldLoc = weld(:,1:3);
    weldLen = weld(:,4)*scaleFactor;
    
    DataWeld(nWeld)   = struct();
    for ii=1:nWeld
        projPt      = zeros(nImg,2);
        cropBox     = zeros(nImg,4);
        
        % weld location
        S   = weldLoc(ii,:);
        
        for jj=1:nImg
            % projection matrix (please refer to the original paper)
            PS  = ImgStruct(jj).P; % s indicates the SfM coordinate
            PT  = PS*inv(M); % t indicates the TRI coordinate
            
            % projection point
            tmp = PT * [S';1];
            projPt(jj,:) = transpose(tmp(1:2)/tmp(3)); clearvars tmp;
            
            % Appendix A
            [K, R, CC, pp, pv] = decomposecamera(PT);
            
            fx          = K(1,1)/K(3,3);
            fy          = K(2,2)/K(3,3);
            x0          = pp(1);
            y0          = pp(2);
            
            CS_prev     = R*(S-CC')';
            CS          = CS_prev/norm(CS_prev);
            
            alpha       = CS(1);
            beta        = CS(2);
            gamma       = CS(3);
            
            theta       = asin(weldLen(ii)/2/norm(CS_prev));
            
            lambda  = alpha/gamma;
            mu      = beta/gamma;
            sigma   = cos(theta)/gamma;
            
            A = lambda^2-sigma^2;
            B = 2*lambda*mu;
            C = mu^2-sigma^2;
            D = 2*lambda;
            E = 2*mu;
            F = 1-sigma^2;
            
            BBx1 = (2*C*C*D-C*B*E)^2;
            BBx2 = (-B*B*C+4*A*C*C)*(-C*E*E+4*C*C*F);
            BBx3 = (-B*B*C+4*A*C*C);
            BBx  = 2*fx*abs(sqrt(BBx1-BBx2)/BBx3);
            
            BBy1 = (2*A*A*E-A*B*D)^2;
            BBy2 = (-A*B*B+4*A*A*C)*(-A*D*D+4*A*A*F);
            BBy3 = (-A*B*B+4*A*A*C);
            BBy  = 2*fy*abs(sqrt(BBy1-BBy2)/BBy3);
            
            cropBox(jj,:)= [projPt(jj,1)-BBx/2,projPt(jj,2)-BBy/2,BBx,BBy];
        end
        DataWeld(ii).projPt  = projPt;
        DataWeld(ii).cropBox = cropBox;
    end
    
    %% Apply two constraints ----------------------------------------------
    %
    % Please see section 2.4.
    for ii=1:nWeld
        validWeld = false(nImg,1);
        for jj=1:nImg
            imgSize = ImgStruct(jj).imgSize; % image size
            
            x   = DataWeld(ii).projPt(jj,1);
            y   = DataWeld(ii).projPt(jj,2);
            BBx = DataWeld(ii).cropBox(jj,3);
            BBy = DataWeld(ii).cropBox(jj,4);
            cond1 = min(BBx,BBy) > TPRatio*weldLen(ii);
            
            xmin = x-BBx/2;     xmax = x+BBx/2;
            ymin = y-BBy/2;     ymax = y+BBy/2;
            cond2 = (xmin>0 && ymin>0) && ...
                        (xmax<imgSize(1) && ymax<imgSize(2));
            if and(cond1, cond2)
                validWeld(jj) = true;
            end
        end
        DataWeld(ii).validWeld = validWeld;
    end
    save(fullfile(folderOutData,'DataWeld.mat'),'DataWeld');
else
    load(fullfile(folderOutData,'DataWeld.mat'),'DataWeld');
end

