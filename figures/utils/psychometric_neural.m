% Figure2b

% Fig2b-- Neural psychometric curve
load res_cell_ac_sfn

binning=3;
x_all = -12:2:12;
ymat = nan(length(res_cell_ac_sfn),length(x_all));
for fctr = 1:length(res_cell_ac_sfn)
 
    numtrials = length(res_cell_ac_sfn(fctr).lr_cue_onset);
    cuecount = zeros(numtrials,2);
    for l=1:numtrials
        cuecount(l,:) = sum(res_cell_ac_sfn(fctr).lr_cue_onset{l});
    end
        
    cuediff = diff(cuecount,[],2);
    choices = double(res_cell_ac_sfn(fctr).all_choices_gd);
    Rchoice = max(choices);
    
    cur_x=unique(cuediff);
    
    clear went_R went_total
    for k=1:length(cur_x)
        curinds = find(cuediff==cur_x(k));
        went_R(k) = sum(choices(curinds)==Rchoice);
        went_total(k) = length(curinds);
    end
    
    went_Right_binned_= filter(ones(1,binning),1,went_R);
    went_Right_binned = went_Right_binned_(binning:end);
    went_total_binned_ = filter(ones(1,binning),1,went_total);
    went_total_binned = went_total_binned_(binning:end);
           
    cur_propR = went_Right_binned./went_total_binned;
        
    clear cur_x_binned
    for k3 = 2:length(cur_x)-1
        cur_x_binned(k3-1) = sum(cur_x(k3-1:k3+1)'.*went_total(k3-1:k3+1))/sum(went_total(k3-1:k3+1));
    end
    
    ymat(fctr,:) = interp1(cur_x_binned,cur_propR,x_all); % translate all curves into common coordinates
        
end

ftype = fittype('a*(1/(1+exp(-x/b)))*(1-lr)+0.5*lr+bias'); %logistic function for fit
[fog,gof] = fit(x_all',nanmean(ymat)',ftype,'StartPoint',[1 .5 0 0]);
fitted = fog(x_all);

%plotting
figure %fig1c
clf;hold on
plot(x_all,ymat,'Color',[0.7 0.7 0.7]);shg
errorbar(x_all,nanmean(ymat),nanstd(ymat)./sqrt(sum(~isnan(ymat))),'o','MarKerFaceColor',[.2 .2 .2],'Color',[.2 .2 .2 ],'LineWidth',1);shg
plot(x_all,fitted,'k','LineWidth',2);shg
axis([-13 13 0 1])
set(gca,'FontSize',14)
xlabel('#R - #L')
ylabel('Proportion went Right')
title('Figure 1c')
