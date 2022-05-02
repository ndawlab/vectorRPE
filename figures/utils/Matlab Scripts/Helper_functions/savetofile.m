function savetofile(data,filename,dataname)
if nargin<3
    dataname = 'data';
end
eval([dataname,'=data;'])
    save(filename,dataname);
end