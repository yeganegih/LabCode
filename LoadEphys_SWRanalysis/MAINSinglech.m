%% loading data
% important note: lines that you may change like file name, are commented
% with multiple percent signs (%%%%%%%%%%)

clear all; clc; close all;
addpath('D:\github\matlab-plot-big'); % add library for faster large data plots
% selecting folder
addpath(genpath('D:\zf\70-86\2019-05-24')); %%%%%%%%%
filename = '100_CH8.continuous'; %%%%%%%
fs=30000; %%%%%%%%% sampling rate for single unit recordings
%      chunk==1 % load a portion of file or totally
%     fid=fopen(filename);
%     fsize = getfilesize(fid);
%     start=1; finish=round(10000000);
%     [signal0, time, info, final_sample] = load_open_ephys_data_chunked(filename,start,finish);

[signal0, time, info] = load_open_ephys_data(filename);

d=30; % downsampling ratio
[signal0]=downsample(signal0,d); fs=fs/d; %%%%%%%%%%%
[time]=downsample(time,d); fs=fs/d; %%%%%%%%%%%
% trimming data
% signal0=signal0( 1:round( length(signal0)/2) ); %%%%%%%%%%%%%%
% time=time( 1:round( length(time)/2) );
plot_time=[0 2]; %%%%%%%%%

%% Filtering
% prefiltering for power-line removal
wo = 50/(fs/2);  bw = wo/65; [b,a] = iirnotch(wo,bw); signal0=filtfilt(b,a,signal0);
% filtering for sharp wave:
ShFilt = designfilt('bandpassiir','FilterOrder',2, 'HalfPowerFrequency1',2,'HalfPowerFrequency2',8, 'SampleRate',fs);
ShrpSig=filtfilt(ShFilt,signal0);
% for ripples
RippFilt = designfilt('bandpassiir','FilterOrder',2, 'HalfPowerFrequency1',40,'HalfPowerFrequency2',280, 'SampleRate',fs);
RippSig=filtfilt(RippFilt,signal0);
beep;
%% figures
% Fig 1 (Raw)
plot_time=[0 600]; %%%%%%%%%
figure,
subplot(4,1,1); o1=plotredu(@plot,time/3600,signal0); title('Raw signal ' )
ylabel('(\muV)'); xlim(plot_time)
% Fig 1 (SW & R)
subplot(4,1,2); o2=plotredu(@plot, time,ShrpSig,'k');
title('Filtered 2-8Hz (LFP)' ); ylabel('(\muV)'); xlim(plot_time);
subplot(4,1,3); o3=plotredu(@plot,time,RippSig,'r');
title('Filtered 80-300Hz (SWR)' ); ylabel('(\muV)'); xlabel('Time (Sec)')
xlim(plot_time);
% Fig 1 ( ShR )
subplot(4,1,4);
plotredu(@plot,time,ShrpSig+RippSig,'b'); title('LFP + SWR' ); ylabel('(\muV)'); xlabel('Time (Sec)'); xlim(plot_time);
%% spike detection
clear ShrpSig % no need any more
% filtering for spike band
SpkFilt = designfilt('bandpassiir','FilterOrder',4, 'HalfPowerFrequency1',300,'HalfPowerFrequency2',3000, 'SampleRate',fs);
SpkSig=filtfilt(SpkFilt,signal0);
tr=5*median(abs(SpkSig))/.674; % threshold for spike detection = 4STD of noise
up_tresh=abs(SpkSig).*(abs(SpkSig)>tr);
[~,spk_times] = findpeaks(up_tresh(fs/1000+1:end),'MinPeakDistance',fs/1000); % Finding spike peaks, while omitting 1st msec, and considering 1 msec recovery
spk_times=spk_times+fs/1000; % shifting 1 msec to the right place
spikes=zeros(length(spk_times),2*fs/1000+1); % empty spike matrix
n=1;
while n <= length(spk_times)
    spikes(n,:)=SpkSig(spk_times(n)-fs/1000 : spk_times(n)+fs/1000); n=n+1;
end

% deleting artefacts
AmpOK_ind=max(spikes,[],2)<100; %%%% only accept the detected spikes that their peak is less than 150 uV
spikes=spikes(AmpOK_ind,:);
figure;
plot((1:2*fs/1000+1)/fs*1000,spikes'); axis tight; xlabel('Time (ms)'); ylabel('Amplitude (\muV)')


%% spike sorting
X=spikes;
Mx=mean(X);

XX=[];YY=[];
for i=1:size(X,2)
    XX(:,i)=X(:,i)-Mx(i);
end
[U,S,V]=svd(XX,'econ');
% Performing PCA and reducting feature space dimension
V=V(:,1:8);
projpca=XX*V;
units=2; %%%%%%%%%% number of putative neurons
idx = kmeans(projpca(:,1:8),units); % clustering
% plotting
X=projpca(1:min(1000,size(spikes,1)),1:3);
idx_plot=idx(1:min(1000,size(spikes,1)));
figure;
plot3(X(idx_plot==1,1),X(idx_plot==1,2),X(idx_plot==1,3),'r.','MarkerSize',12); hold on;
plot3(X(idx_plot==2,1),X(idx_plot==2,2),X(idx_plot==2,3),'b.','MarkerSize',12)
plot3(X(idx_plot==3,1),X(idx_plot==3,2),X(idx_plot==3,3),'g.','MarkerSize',12)
plot3(X(idx_plot==4,1),X(idx_plot==4,2),X(idx_plot==4,3),'m.','MarkerSize',12)
xlabel('PC1');ylabel('PC2');zlabel('PC3'); axis tight
%% sorted spikes in one plot
figure;
subplot(1,units,1);   plot(((1:2*fs/1000+1)/fs*1000)-1,spikes(idx==1,:)','r'); axis([-1 1 -100 100 ]); xlabel('Time (ms)');    ylabel('Amplitude (\muV)');
SpkMean(1,:)=mean(spikes(idx==1,:)); hold on, plot(((1:2*fs/1000+1)/fs*1000)-1,SpkMean(1,:),'k','linewidth',2);
text(-.9,90,['#  ' num2str(sum(idx==1))]);
if units>1
    subplot(1,units,2);   plot(((1:2*fs/1000+1)/fs*1000)-1,spikes(idx==2,:)','b'); axis([-1 1 -100 100 ]); xlabel('Time (ms)');    end
SpkMean(2,:)=mean(spikes(idx==2,:)); hold on, plot(((1:2*fs/1000+1)/fs*1000)-1,SpkMean(2,:),'k','linewidth',2);
text(-.9,90,['#  ' num2str(sum(idx==2))]);
if units>2
    subplot(1,units,3);   plot(((1:2*fs/1000+1)/fs*1000)-1,spikes(idx==3,:)','g'); axis([-1 1 -100 100 ]); xlabel('Time (ms)');    end
SpkMean(3,:)=mean(spikes(idx==3,:)); hold on, plot(((1:2*fs/1000+1)/fs*1000)-1,SpkMean(3,:),'k','linewidth',2);
text(-.9,90,['#  ' num2str(sum(idx==3))]);
if units>3
    subplot(1,units,4);   plot(((1:2*fs/1000+1)/fs*1000)-1,spikes(idx==4,:)','m'); axis([-1 1 -100 100 ]); xlabel('Time (ms)');    end
SpkMean(4,:)=mean(spikes(idx==4,:)); hold on, plot(((1:2*fs/1000+1)/fs*1000)-1,SpkMean(4,:),'k','linewidth',2);
text(-.9,90,['#' num2str(sum(idx==4))]);
colors={'r','b','g','m'}; % so the colors for future plots

spk_times_sort={};
for unit=1:units
    spk_times_sort{unit}=spk_times(idx==unit)/fs;
end

%% Ripple detection
uniRip=abs(RippSig); % ripple signal rectified for one-sided thresholding
detRip=filtfilt(ones(1,fs/20)/(fs/20),1,uniRip); detRip=detRip/std(detRip); % one-sided signal smoothed and normalized
figure % figure for sharp wave detection
subplot(4,1,1);
plot(time,signal);  title('Raw signal'); ylabel('(\muV)'); xlim(plot_time);
subplot(4,1,2)
plot(time,RippSig), title('Ripples'); ylabel('(\muV)');    xlim(plot_time);
subplot(4,1,3)
plot(time,detRip),  title('Detection signal');             xlim(plot_time);
SD=median(detRip)/.67;  Tr=4*SD; % detection criteria is a factor of std of signal
hold on; line(plot_time , [Tr Tr],'Color','red','LineStyle','--')
% detection of sharp waves
up_tresh=abs(detRip).*(abs(detRip)>Tr);
[~,Rip_times] = findpeaks(up_tresh(fs+1:end-fs),'MinPeakDistance',fs/4); % Finding peaks, while omitting 1st sec, and considering minimum
% 250 m sec interval between concequent sharp waves
Rip_t=Rip_times+fs; % shifting 1 sec to the right place
% adding detected ripple times to the last plot
plot(Rip_t/fs,detRip(Rip_t),'rv'); xlim(plot_time);
ylabel('SD');
% Spike Train
subplot(4,1,4)
hold on
for unit=1:units
    spk_time=spk_times_sort{unit};
    for i=1:length(spk_time)
        y=units-unit;
        line([spk_time(i) spk_time(i)],[y+.2 y+.8],'color',colors{unit},'linewidth',1);
    end
end
set(gca,'yticklabels',''); set(gca,'ytick',[]);
xlabel('Time (sec)','fontweight','normal');
title('raster plot','fontweight','bold');
xlim ([plot_time(1) plot_time(2)]); set(gca,'box','off'); ylim([0 units]);

%% Ripple-related raster plot
clear edges N F_ T_ P_
figure;
subplot(9,1,1:4)
spkRip=cell(units,1); % for keeping spike times occuring in the temporal vicinity of ripples, so for any ripple, we append spike times of any unit, to the corresponding row ...
% of this variable
nRip=length(Rip_times); % number of ripples to show spiking pattern for.
T=.25; % Time around the SWR complex to analyze
for k=1:nRip % first loop through ripples
    t1=Rip_t(k)-T*fs;
    t2=Rip_t(k)+T*fs;
    for unit=1:units % second loop for units, each unit in different color
        spk_time=spk_times_sort{unit};
        Indx=(spk_time*fs>t1 & spk_time*fs<t2);
        spk_t=spk_time(Indx)*fs-Rip_t(k);
        plot(spk_t/fs,k*ones(1,length(spk_t)),'.','color',colors{unit},'markersize',5) ; hold on
        spkRip{unit,:}=[spkRip{unit,:} , spk_t'/fs];
    end
end
line([0 0], [0 nRip],'Color','black','LineStyle','--'); ylabel('Ripple #'); xticks([]); ylim([0 nRip])
text(.05,nRip+10,'Ripple-triggered spike activity'); xlim([-T T+0.001]); box off

% firing rates
subplot(9,1,5:6)
for unit=1:units
    % plot for histogram:
    [N(unit,:),edges] = histcounts(spkRip{unit,:}, round(nRip*.8));  cntr=edges(1:end-1)+diff(edges); bin=edges(2)-edges(1);
    h=bar(cntr,N(unit,:)/(bin*nRip),'FaceColor',colors{unit},'FaceAlpha',.4,'EdgeAlpha',0); hold on
    % plot for fitted curves:
    %      f=fit(cntr',N(unit,:)','smoothingspline');  plot(f);
end
line([0 0], [0 max(N(:)/(bin*nRip))],'Color','black','LineStyle','--');xticks([]);
axis([-T T+0.001 0 max(N(:)/(bin*nRip))]); ylabel('spk/sec'); legend('off')
text(0.18,max(N(:)/(bin*nRip))+5,'firing rates'); box off

% spiking distribution boxplot
subplot(9,1,7) % we would like to add a boxplot of dispersion of spike times around SWR. First we shall determine how many spikes we have in eac time bin:
datapoints=cell(units,1);
for unit= 1:units
    for bin=cntr
        datapoints{unit,:}=[datapoints{unit,:} cntr(cntr==bin)*ones(1,N(unit,cntr==bin))];
    end
    % padding with NaN, why? Because the number of spikes are not the same for
    % the different neurons, so this way, creation of boxplot is easier
    datapoints{unit,:}=[datapoints{unit,:} NaN(1,sum(N(:))-length(datapoints{unit,:})  )];
end
line([0 0], [0 units+1],'Color','black','LineStyle','--'); hold on % zero line (start of SWR)
boxplot(cell2mat(datapoints)','orientation','horizontal','color','rbgm','width',.7,'symbol','w','whisker',0);
ylabel('units')
xlim([-T T+0.001]); xticks([]); text(.05,units+.8,'temporal distribution of firings'); box off

% Time-Frequency spectrum of LFP surrounding ripple initiation
for rip=1:10
    t0=Rip_t(rip);
    freq=4:10:270; %Frequencies we are interested in
    % dertermining number of samples around the ripple onset to analyze:
    min_freq=2;
    nsmpl=round((1/min_freq)*2*fs);
    n=2^(nextpow2(nsmpl)-1); %Number of points in moving window
    indRip =t0-nsmpl:t0+nsmpl; % samples surrounding a ripple onset
    [~,F_,T_,P_(:,:,rip)]=spectrogram(signal(indRip),n,round(.80*n),freq,fs,'yaxis');
    maxDb=20; %Maximum on scale for decibels.
end
Prip=sum(P_,3);
%Plot spectrogrm
subplot(9,1,8:9)
surf((T_-nsmpl/fs)*1000,F_,10*log10(Prip)); colormap('jet'); shading interp; view(0,90)
axis([[-T T+.001]*1000, 0 max(freq)]); xlabel('Time (m sec)'); ylabel('Frequency (Hz)');  colorbar off
hold on; plot3([0 0], F_([1 end]),max(Prip(:))*[1.1 1.1],'Color','black','LineStyle','--');
text(75,max(freq)+12,'LFP spectrogram (SW-R)'), box off