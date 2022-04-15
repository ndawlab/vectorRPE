
slashsymbol = '\';
if isunix || ismac
    slashsymbol = '/';
end

cur_namepath = mfilename('fullpath');
base_folder = cur_namepath(1:end-12);

addpath(genpath(base_folder))

folder_fulltraces = [base_folder,'Data',slashsymbol,'FullT_ac_sfn',slashsymbol];
folder_interim    = [base_folder,'Data',slashsymbol,'interim_saves',slashsymbol];
folder_shuffled   = [base_folder,'Data',slashsymbol,'shuffled_data',slashsymbol];
folder_pavlov     = [base_folder,'Data',slashsymbol,'pavlovian_data',slashsymbol];

save folder_list base_folder folder_fulltraces folder_interim folder_shuffled folder_pavlov     

