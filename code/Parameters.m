%% Autonmous Image Localization for Visual Inspection of Civil Structure
%
%% Contact
%  Name  : Chul Min Yeum
%  Email : chulminy@gmail.com
%  Please contact me if you have a question or find a bug. You can use a
%  "issues" page in the github.

%% Description
%
% This code is used for the following paper:
% Chul Min Yeum, Jongseong Choi, and Shirley J. Dyke. “Autonomous image
% localization for visual inspection of civil infrastructure” accepted for
% Smart Materials and Structures (2016).
%
% Since a large volume of images are processed, it takes a long time for
% processing. GPU and parellel processing will be great helpful for some of
% process.

% This code is tested under only window machine so you may find errors in
% other OS, but it may be trivial related with setting up file pathes
% or toolbox download in "Parameters". I am open to assist you to work this
% code on differt OS.
%
% Also, ReadB2ASCII.cxx need to be compile in your machine if it is not
% working
%
% You can feel free to modify this code but I would ask you citing my
% paper if it is useful.

%% Reference
% 
% Chul Min Yeum, Jongseong Choi, and Shirley J. Dyke. “Autonomous image
% localization for visual inspection of civil infrastructure” accepted for
% Smart Materials and Structures (2016).

clear; clc; close all; format shortg; warning off;

isGPU       = true;

%% GPU device activate
if isGPU
    if gpuDeviceCount ==0;
        isGPU = false;
    end
end

%% Include external codes
folderExternal = 'external';
if ~exist(folderExternal); mkdir(folderExternal); end;
addpath(genpath('misc'));

%% Installation of a VLFEAT toolbox (one-time process)
% If there is error in this code block, you can manually install vlfeat in
% your machine.
% Please check out the following website: http://www.vlfeat.org/
vlfeat_link = 'http://www.vlfeat.org/download/vlfeat-0.9.18-bin.tar.gz';
if ~exist('vl_version','file')
    untar(vlfeat_link,folderExternal);
    run(fullfile(folderExternal,'vlfeat-0.9.18','toolbox','vl_setup'));
    savepath;
end; clearvars vlfeat_link

%% Installation of a Peter Kovesi CV and IP toolbox
% If there is error in this code block, you can manually install the code
% in your machine. Please check out the following website:
% Please check out the following website: http://www.peterkovesi.com/
Kovesi_link = 'http://www.peterkovesi.com/MatlabFns.zip';
if~exist(fullfile(folderExternal,'MatlabFns'),'dir')
    unzip(Kovesi_link,folderExternal);
    addpath(genpath(fullfile(folderExternal,'MatlabFns'))); 
else
    addpath(genpath(fullfile(folderExternal,'MatlabFns'))); 
end; clearvars Kovesi_link

%% Installation of piotr's computer vision toolbox
% If there is error in this code block, you can manually install the code
% in your machine. Please check out the following website:
% https://github.com/pdollar/toolbox
pdol_link = 'https://pdollar.github.io/toolbox/archive/piotr_toolbox.zip';
if  ~exist(fullfile(folderExternal,'toolbox'),'dir')
    unzip(pdol_link,folderExternal);
    addpath(genpath(fullfile(folderExternal,'toolbox'))); 
else
    addpath(genpath(fullfile(folderExternal,'toolbox'))); 
end; clearvars pdol_link

%% Installation of MATLAB Functions for Multiple View Geometry
% If there is error in this code block, you can manually install vlfeat in
% your machine. Please check out the following website:
% http://www.robots.ox.ac.uk/~vgg/hzbook/code/
mv_link = 'http://www.robots.ox.ac.uk/~vgg/hzbook/code/allfns.zip';
if  ~exist(fullfile(folderExternal,'allfns'),'dir')
    unzip(mv_link,fullfile(folderExternal,'allfns'));
    addpath(genpath(fullfile(folderExternal,'allfns'))); 
else
    addpath(genpath(fullfile(folderExternal,'allfns'))); 
end; clearvars mv_link


%% Image and data folder setup --------------------------------------------
pathData        = fullfile(cd(cd('..')),'data');
folderInInfo    = fullfile(pathData, 'info');

% input folder and data----------------------------------------------------
folderIn        = fullfile(pathData,'in');
folderInImg     = fullfile(folderIn,'img');  % original raw image

% input files

% reference point registration
foderRefer      = fullfile(folderIn,'refer');

% nvm file generated from VisualSFM
nvmFile         = fullfile(folderIn,'truss.nvm'); 

% reference points
refPointFile    = fullfile(folderIn,'loc_ref.mat');

% weld location
weldLocFile     = fullfile(folderIn,'weld_loc.mat');
% -------------------------------------------------------------------------

% output folder and data---------------------------------------------------
folderOut            = fullfile(pathData,'out');
folderOutImgUndist   = fullfile(folderOut,'undist'); 
folderOutData        = fullfile(folderOut,'prc_data');

clearvars pathData ;
% -------------------------------------------------------------------------

%% Parameters ------------------------------------------------

% scaling factor for weld length
scaleFactor = 2; 
TPRatio = 1; % 1pixel/1mm (see section 3.3)

% You can compute working distance using this code
%{
% Computation of working distance 
% these values only work for D90 Nikon
FL      = 18 * 10^-3;   % camera focal length (m)
SR      = 4288;         % camera sensor resolution (pixel)
SS      = 23.6 * 10^-3; % camera sensor size (m)
TP      = 126;
TS      = 63.5*2;
WD      = zeros(1000,1);
for ii=1:1000
    alpha   = rand*pi/3;
    beta    = rand*(pi/2-0.92)+0.92;
    WD(ii) = FL*SR/SS/TP*TS*sin(beta-alpha)/sin(pi-beta) + TS*sin(alpha)/2;
end; 
mean(WD); % working distance.
%}
