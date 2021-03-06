function SP_RecFunc
% make your own function for splitlab
%
% this takes theselected time window performs a operation that you define
% and than gives an example of how to access the final results structure
% 

%% FIRST, make global variables visible to our template.
% config   - contains information on your configuration (directories, etc)
% eq       - is the structure of all earthquake parameters
% thiseq   - contains the paramters of this earthquake (very smart), plus 
%            additional temporary information, eg in thiseq.Amp the amplitude
%            vectors are saved 
global  config eq thiseq

%print info to standard output
fprintf(' %s -- analysing event  %s:%4.0f.%03.0f (%.0f/%.0f) --\n',...
    datestr(now,13) , config.stnname, thiseq.date(1), thiseq.date(7),config.db_index, length(eq));


  
%% extend selection window
%some calculations require an extended tim window to perferm properly
% so this is what we do here
extime_before    = 60 ; 
extime_after    = 60 ; 
o         = thiseq.Amp.time(1);%common offset of all files after hypotime
extbegin  = floor( (thiseq.a - extime_before - o) / thiseq.dt); %index of first element of amplitude verctor of the selected time window
extfinish = floor( (thiseq.a + extime_after - o) / thiseq.dt); %index of last element
extIndex  = extbegin:extfinish;%create vector of indices to elements of extended selection window

% now find indices of selected window, but this time 
% relative to extended window, defined above

%ex = floor(extime/thiseq.dt) ;
%w  = (ex+1):(length(extIndex)-ex);


%% OK, now we can define our seismogram components windows
E =  thiseq.Amp.East(extIndex);
N =  thiseq.Amp.North(extIndex);
Z =  thiseq.Amp.Vert(extIndex);

Q = thiseq.Amp.Radial(extIndex)';
T = thiseq.Amp.Transv(extIndex)';
L = thiseq.Amp.Ray(extIndex)';


%% Filtering
% the seismogram components are not yet filtered
% define your filter here.
% the selected corner frequncies are stored in the varialbe "thiseq.filter"
% 
ny    = 1/(2*thiseq.dt);%nyquist freqency of seismogramm
n     = 3; %filter order

f1 = thiseq.filter(1);
f2 = thiseq.filter(2);
if f1==0 && f2==inf %no filter
    % do nothing
    % we leave the seismograms untouched
else
    if f1 > 0  &&  f2 < inf
        % bandpass
        [b,a]  = butter(n, [f1 f2]/ny);
    elseif f1==0 &&  f2 < inf
        %lowpass
        [b,a]  = butter(n, [f2]/ny,'low');

    elseif f1>0 &&  f2 == inf
        %highpass
        [b,a]  = butter(n, [f1]/ny, 'high');
    end
    Q = filtfilt(b,a,Q); %Radial     (Q) component in extended time window
    T = filtfilt(b,a,T); %Transverse (T) component in extended time window
    L = filtfilt(b,a,L); %Vertical   (L) component in extended time window
    
    E = filtfilt(b,a,E); 
    N = filtfilt(b,a,N);
    Z = filtfilt(b,a,Z);
end

%% do some detrending of extended time window
    E = detrend(E,'constant');
    E = detrend(E,'linear');
    N = detrend(N,'constant');
    N = detrend(N,'linear');
    Z = detrend(Z,'constant');
    Z = detrend(Z,'linear');
    
    Q = detrend(Q,'constant');
    Q = detrend(Q,'linear');
    T = detrend(T,'constant');
    T = detrend(T,'linear');
    L = detrend(L,'constant');
    L = detrend(L,'linear');
    
%% XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
%%                P U T     Y O U R    C O D E    H E R E
%% XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
% here you can start with your own coding;
% you should make use of the global "config" and "thiseq" variable to get
% information about the station (lat, long) and earthquake (bazi, depth).
%
% any of your results may be stored temporarily in a variable within thiseq
% something like     
%    thiseq.MyVariable=[max(E) max(N) max(Z)];
%% Receiver function parameters
Shift = 60; %RF starts at 10 s
f0 = 1.5; % pulse width
niter = 400;  % number iterations
minderr = 0.001;  % stop when error reaches limit
RFlength = length(extIndex);
timeaxis = - Shift  + thiseq.dt*(0:1:RFlength-1);
time = - extime_after  + thiseq.dt*(0:1:RFlength-1);
%enf = 3;
% Rotation to T-R-Z
seis = rotateSeisENZtoTRZ( [E, N, Z] , thiseq.bazi );
T = seis(:,1);
R = seis(:,2);
Z = seis(:,3);

%% Rotate to P-SV-SH
Alpha = 5;
startime = extime_before / thiseq.dt;
W=input('enter the window width (s): ');
for t=1:length(T)
winbegin  = t - floor( W/2 / thiseq.dt);
winfinish = t + floor( W/2 / thiseq.dt);
if winbegin <= 0 
    winbegin = 1;
elseif winfinish >= length(T)
    winfinish =length(T);
end
winIndex  = winbegin:winfinish;

%   winT =  T(winIndex);
    winR =  R(winIndex);
    winZ =  Z(winIndex);

% Caculate the covariance matrix
V = cov(winR,winZ);
% calculating the eigenvalues and the eigenvectors
[Ve,d]=eig(V);
e1=Ve(:,1);e2=Ve(:,2); %e1=[eZ1,eR1]T;e2=[eZ2,eR2]T
d1=d(1,1);d2=d(2:2);
if e1(1)/e1(2) > tan(Alpha) || e1(1)/e1(2) < -1/tan(Alpha)
    OP = [1;0];
    OS = [0;1];
elseif e1(1)/e1(2) < tan(Alpha) && e1(1)/e1(2) < -1/tan(Alpha)
    OP = [0;1];
    OS = [1;0];
end
P(t) =  [Z(t) R(t)]*Ve*OP;
SV(t) = [Z(t) R(t)]*Ve*OS;
end

%% Reverse the time axis
% seis = flipud(seis);
% %[thiseq.SP_RF, thiseq.RMS,thiseq.it_num] =  makeRFwater_ammon( seis(:,3), seis(:,2), 0, thiseq.dt, RFlength, ...
% 					      %0.001, f0, 0);
%              %plot(time,-thiseq.SP_RF,'r','linewidth',1.5);set(gca,'xlim',[min(time) max(time)]);
%              %pause
% figure(9)
% subplot(3,1,1);
% plot(time,seis(:,1),'b','linewidth',1.5);set(gca,'xlim',[min(time) max(time)]);hold on
% legend( 'T' ); legend boxoff
% subplot(3,1,2);
% plot(time,seis(:,2),'k','linewidth',1.5);set(gca,'xlim',[min(time) max(time)])
% legend( 'R' ); legend boxoff
% subplot(3,1,3);
% plot(time,seis(:,3),'r','linewidth',1.5);set(gca,'xlim',[min(time) max(time)])
% legend( 'Z' ); legend boxoff
% 
% %Rotate to P-SV-SH for a set of INC
% %time = - extime_after  + thiseq.dt*(0:1:RFlength-1);
% INC = 3:3:60;
% Rot_seis = zeros(length(INC),size(seis,1),size(seis,2));
% figure(10);clf;
% set(gcf, 'OuterPosition', get(0,'Screensize')); % Maximize figure.
% %h10=subplot(1,1,1);
% for i = 1:length(INC)
% Rot_seis(i,:,:) = rotateSeisTRZtoTLQ( seis , INC(i) );
% %[test_SP, ~,~] = makeRFitdecon_la(Rot_seis(i,:,2), Rot_seis(i,:,3), thiseq.dt, RFlength, Shift, f0, ...
% 				 %200, minderr);
% subplot(4,5,i);
% plot(time,Rot_seis(i,:,2),'r','linewidth',1.5);hold on;plot(time,Rot_seis(i,:,3),'k','linewidth',1.5);
% set(gca,'xlim',[0 30],'ylim',[min([seis(1:round(30/thiseq.dt),2);seis(1:round(30/thiseq.dt),3)]) max([seis(1:round(30/thiseq.dt),2);seis(1:round(30/thiseq.dt),3)])]);
% set(gca,'YGrid','on','XGrid','on');
% %plot([0 0],ylim,'r','linewidth',1);plot(xlim,[0 0],'r','linewidth',1);
% %test_SP = - test_SP;
% %pos = zeros(1,RFlength); neg = zeros(1,RFlength);
% %[posrow,poscol,~] = find(test_SP  > 0); [negrow,negcol,~] = find(test_SP  < 0);
% %pos(posrow,poscol) = enf*test_SP(posrow,poscol); neg(negrow,negcol) = enf*test_SP(negrow,negcol);
% %yy = i*ones(1,RFlength); hold on;
% %pos = pos+i;neg = neg+i;
% %posX=[timeaxis,fliplr(timeaxis)];posY=[pos,fliplr(yy)];
%    % fill(posY,posX,[.8 .8 .8],'EdgeColor','none','LineStyle','-');
%    % negX=[timeaxis,fliplr(timeaxis)];negY=[neg,fliplr(yy)];
%     %fill(negY,negX,[.3 .3 .3],'EdgeColor','none','LineStyle','-');
%     %test_SP = enf*test_SP + i;
%     %plot( h10,test_SP,timeaxis,'black','lineWidth',0.6); hold on;  
%     %box on; 
% %plot(timeaxis,(-1) * test_SP,'k');
% %set(gca,'xlim',[-5 20],'ylim',[-0.5 0.5],'xtick',(0:2:20),'Xgrid','on','Ygrid','on')
% title(['INC angle: ' num2str(INC(i)) '\circ'],'FontName','Times new roman','FontSize',11,'FontWeight','bold');
% end
% %set(h10,'ytick',[-2:1:20],'ylim',[-2 20],'xlim',[0 length(INC)+1],'FontName','Times new roman','FontSize',11,'FontWeight','bold');
% %set(h10, 'YGrid','off','lineWidth',1);
% %set(h10,'xtick',[1:1:length(INC)],'xticklabel',num2str(INC','%u\n'));
% %set(h10,'Xaxislocation','bottom','YDir','reverse');
% %xlabel(h10,['Indicent angle (' '\circ' ')'],'FontSize',16); ylabel(h10,'Time (s)','FontSize',16);
% %plot(h10,xlim,[0,0],'-','linewidth',1.0,'color','k');plot(h10,xlim,[4,4],'-','linewidth',1.0,'color','r');
% %INQUIRE the optimum INC
% real_INC = input('INPUT the best incidence angle: ');
% seis = rotateSeisTRZtoTLQ( seis , real_INC );
% SH = seis(:,1);
% P = seis(:,2);
% SV = seis(:,3);
% close(figure(9))
% close(figure(10))


%Make SP Receiver functions

% [thiseq.SP_RF, thiseq.RMS,thiseq.it_num] = makeRFitdecon_la_SP( P, SV, thiseq.dt, RFlength, Shift, f0, ...
% 				 niter, minderr);
[thiseq.SP_RF, thiseq.RMS,thiseq.it_num] =  makeRFwater_ammon( P, SV, Shift, thiseq.dt, RFlength, ...
					      0.01, f0, 0);

%Reverse the sign of SP_RF amplitudes

thiseq.SP_RF = - thiseq.SP_RF;
thiseq.SP_RF = fliplr(thiseq.SP_RF);

%plot RF
figure(12);
% clf;

%subplot(3,1,1);plot(timeaxis,SV,'k');
%subplot(3,1,2);plot(timeaxis,SH,'k');
%subplot(3,1,3);plot(timeaxis,P,'k');
%pause
plot(timeaxis,thiseq.SP_RF,'k');
set(gca,'xlim',[-10 extime_after],'xtick',(-10:5:extime_after),'Xgrid','on','Ygrid','on')
%% XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
%%              R E S U L T   S A V E   T E M P L A T E
%% XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
% assume you stored your output in the global variable "thiseq.MyVariable"
% Then you pose a question, if the user wants to save this result (see  the 
% Matlab function QUESTDLG). We have to transmit this result now from temporary
% thiseq to the permanent project variable "eq"
% the index of thiseq in the permanent eq structure is given by the varible
% thiseq.index (very smart...)
%

OUT_path = ['F:\ahzjanisotropy\ahzj_SP_RF\' config.stnname];
button = MFquestdlg( [ 0.4 , 0.12 ] ,'Do you want to keep the result?','SP_RecFunc',  ...
    'Yes','No','Yes');

if strcmp(button, 'Yes')
     if( ~exist( OUT_path , 'dir') )
     mkdir( OUT_path ); end
     fid_iter = fopen(fullfile(OUT_path,[config.stnname 'iter_SP.dat']),'a+');     
     fid_finallist = fopen(fullfile(OUT_path,[config.stnname 'finallist.dat']),'a+');
      %OUTPUT SP RFs
        fid_SP = fopen(fullfile(OUT_path,[thiseq.seisfiles{1}(1:14) '_' thiseq.SplitPhase '_SP.dat']),'w+');        
        for ii = 1:RFlength
        fprintf(fid_SP,'%f\n',thiseq.SP_RF(ii));         
        end
        fclose(fid_SP); 
        
        %OUTPUT iteration number
        fprintf(fid_iter,'%s %s %u %f\n',thiseq.seisfiles{1}(1:14),thiseq.SplitPhase,thiseq.it_num,thiseq.RMS(thiseq.it_num));        
        
        %Add the current earthquake to the finallist:
        Ev_para = taupTime('iasp91',thiseq.depth,thiseq.SplitPhase,'sta',[config.slat,config.slong],'evt',[thiseq.lat,thiseq.long]);   
        Ev_para = srad2skm(Ev_para(1).rayParam);
        fprintf(fid_finallist,'%s %s %f %f %f %f %f %f %f\n',thiseq.seisfiles{1}(1:14),thiseq.SplitPhase,thiseq.lat,thiseq.long,thiseq.depth,thiseq.dis,thiseq.bazi,Ev_para,thiseq.Mw);
     %idx = thiseq.index;
     %eq(idx).RadialRF = thiseq.RadialRF;
     %eq(idx).RMS_R = thiseq.RMS_R;
     %eq(idx).it_num_R = thiseq.it_num_R;
     
     %eq(idx).TransverseRF = thiseq.TransverseRF;
     %eq(idx).RMS_T = thiseq.RMS_T;
     %eq(idx).it_num_T = thiseq.it_num_T;
     %you may also want to write a logfile...
     fclose(fid_iter);fclose(fid_finallist);close(figure(11));    

else
clear('thiseq.SP_RF', 'thiseq.RMS','thiseq.it_num')
% close(figure(11));

end

%% XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
%%              R E S U L T   O U T P U T    T E M P L A T E
%% XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
% lastly, how to you access later your results. For example write your
% results to a data files:

% we have to loop over all (permanent) "eq" entries. 
%OUT_path = ['F:\ahzjanisotropy\ahzj_SP_RF\' config.stnname];
%if( ~exist( OUT_path , 'dir') )
    %mkdir( OUT_path ); end

%fid_iter = fopen(fullfile(OUT_path,[config.stnname 'iter_SP.dat']),'a+');
%fid_finallist = fopen(fullfile(OUT_path,[config.stnname 'finallist.dat']),'a+');

%for k = 1:length(eq)
    %tmp=eq(k);
    
    %Now, we look if eq(k).MyVariable is set
    %if isfield(tmp, 'SP_RF') && ~isempty(tmp.SP_RF)
        %OUTPUT Radial RFs
        %fid_SP = fopen(fullfile(OUT_path,[tmp.seisfiles{1}(1:14) '_SP.dat']),'w+');        
        %for ii = 1:RFlength
        %fprintf(fid_SP,'%f\n',tmp.SP_RF(ii));         
        %end
        %fclose(fid_SP);        
        
        
        %OUTPUT iteration number
        %fprintf(fid_iter_SP,'%s %u %f\n',tmp.seisfiles{1}(1:14),tmp.it_num,tmp.RMS(tmp.it_num));        
        
        %Add the current earthquake to the finallist:
        %Ev_para = taupTime('iasp91',tmp.depth,'S','sta',[config.slat,config.slong],'evt',[tmp.lat,tmp.long]);   
        %Ev_para.rayParam = srad2skm(Ev_para.rayParam);
        %fprintf(fid_finallist,'%s %f %f %f %f %f %f %f\n',tmp.seisfiles{1}(1:14),tmp.lat,tmp.long,tmp.depth,tmp.dis,tmp.bazi,Ev_para.rayParam,tmp.Mw);
    %end
    % go to next earthquake
%end
%fclose(fid_iter);fclose(fid_finallist);
