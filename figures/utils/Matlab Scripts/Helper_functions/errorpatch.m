function [h_line,h_sem] = errorpatch(x,means,stds,color,linewidth,show_sem)

if nargin<4
    color = [0 0 1];
end
 if nargin<5
    linewidth = 4;
 end
 if nargin<6
     show_sem=1;
 end
 x = x(:)';
 means=means(:)';
if iscell(stds)
    std1 = stds{1}(:)';
    std2 = stds{2}(:)';        
else
    stds=stds(:)';
    std1 = stds;
    std2 = stds;    
end

if isempty(x)
    x=1:length(means);
end

if length(means)~=length(std1) || length(x)~=length(std1)
    error('lengths of arguments must be equal')
end
goodstart = find(~isnan(means),1,'first');
x = x(goodstart:end);
means=means(goodstart:end);
std1=std1(goodstart:end);
std2=std2(goodstart:end);

switch show_sem
    case 1
  h_sem =  patch([x fliplr(x)],[means+std1 fliplr(means-std2)],1,'FaceColor',color,'EdgeColor','none','FaceAlpha',0.4);shg
    case -1
  h_sem =  patch([x fliplr(x)],[means+std1 fliplr(means-std2)],1,'FaceColor',color,'EdgeColor','none');shg
    case 0
   h_sem = []; 
end
hold on
h_line = plot(x,means,'Color',color,'LineWidth',linewidth); shg
hold off











