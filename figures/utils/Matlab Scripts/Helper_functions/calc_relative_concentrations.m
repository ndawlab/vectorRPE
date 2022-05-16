function pvals = calc_relative_concentrations(xyz_g_sm,do_ap,best_bic,idx2_sm,colrovec)

%axis lims for plotting
xyz_g_sm(:,1) = abs(xyz_g_sm(:,1));
allmin=min(xyz_g_sm)/1e3;
axis_mins = [floor(allmin(1)*100)/100 floor(allmin(2)*100)/100]*1e3;
allmax=max(xyz_g_sm)/1e3;
axis_maxs = [ceil(allmax(1)*100)/100 ceil(allmax(2)*100)/100]*1e3;
cur_axis_lims_ml = [axis_mins(1) axis_maxs(1)];
cur_axis_lims_ap = [axis_mins(2) axis_maxs(2)];

cur_location = abs(xyz_g_sm(:,1));
xi_all = 325:25:850;
cur_axis_lims = cur_axis_lims_ml;
cur_xticks = 300:100:900;
xlabel_str = {'Medial-Lateral','(midline, mm)'};
if do_ap
    cur_location = xyz_g_sm(:,2);
    xi_all = -3.75e3:25:-2.825e3;
    cur_axis_lims = cur_axis_lims_ap;
    cur_xticks = -3.7e3:300:-2.8e3;
    xlabel_str = {'Anterior-Posterior','(bregma, mm)'};
end



% calculate relative densities
clear f_cell
for k=1:best_bic
    [f,xi] = ksdensity(cur_location(idx2_sm==k,1),'Bandwidth',50);
    f_cell{k} = f;xi_cell{k} = xi;
end

clear f_interp
for k=1:best_bic
    f_interp(:,k) = interp1(xi_cell{k},f_cell{k},xi_all);
end

% calculate shuffle densities

numbootiters = 10000;

density_boot = zeros(length(xi_all),best_bic,numbootiters);
rng(0)
for l=1:numbootiters
    if ~mod(l,2000)
        disp(num2str(l))
    end
    idx2_sm_rnd = idx2_sm(randperm(length(idx2_sm)));
    clear f_cell_rnd f_interp_rnd
    for k=1:best_bic
        [f,xi] = ksdensity(cur_location(idx2_sm_rnd==k),'Bandwidth',50);
        f_cell_rnd{k} = f;xi_cell_rnd{k} = xi;
        f_interp_rnd(:,k) = interp1(xi_cell_rnd{k},f_cell_rnd{k},xi_all);
    end
    
    for k=1:best_bic
        density_boot(:,k,l) = f_interp_rnd(:,k)./nansum(f_interp_rnd,2);
    end
    
    
end

clear shuffle_5pct_CI
for k=1:best_bic
    curdenses = squeeze(density_boot(:,k,:));
    for m=1:size(curdenses,1)
        shuffle_5pct_CI(m,k,1) = prctile(curdenses(m,:),2.5);
        shuffle_5pct_CI(m,k,2) = prctile(curdenses(m,:),97.5);
    end
end


figure % fig3e cluster concentrations (densities)
for k=1:best_bic
    subplot(best_bic,1,k)
    cla;hold on
    cur_density = f_interp(:,k)./nansum(f_interp,2);
    cur_density(isnan(cur_density ))=0;
    plot(xi_all,cur_density,'LineWidth',3,'Color',colrovec(k));shg
    patch([xi_all fliplr(xi_all)],[cur_density; zeros(size(xi_all))'],colrovec(k),'EdgeColor','none');shg
    axis([cur_axis_lims 0 max(max(f_interp./repmat(nansum(f_interp,2),1,best_bic)))])
    
    set(gca,'FontSize',14,'XTick',[])
    
    plot(xi_all,shuffle_5pct_CI(:,k,1),'--','LineWidth',1,'Color',[0.3 0.3 0.3]);shg
    plot(xi_all,shuffle_5pct_CI(:,k,2),'--','LineWidth',1,'Color',[0.3 0.3 0.3]);shg
    
end
set(gca,'XTick',cur_xticks)
xlabel(xlabel_str)


clear orig_densities
for k=1:best_bic
    orig_densities(:,k) = f_interp(:,k)./sum(f_interp,2);
end

%std statistic
bootstd = squeeze(nanstd(density_boot));
for k=1:best_bic
    pvals(k) = mean(bootstd(k,:)>nanstd(orig_densities(:,k)));
end

