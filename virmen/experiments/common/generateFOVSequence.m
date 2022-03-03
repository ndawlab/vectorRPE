function [sequenceOfFOVs] = generateFOVSequence(vr)

n=ceil(vr.totalTrials/(2*vr.numberOfFOVs))*(2*vr.numberOfFOVs);
sequenceOfFOVs=zeros(1, n);
t=0:1:(n/2-1);
sequenceOfFOVs(1:2:end)=mod(t, vr.numberOfFOVs);
sequenceOfFOVs(2:2:end)=sequenceOfFOVs(1:2:end);

end