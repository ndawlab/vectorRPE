function [sequenceOfFOVs] = generateFOVSequence4Odor(vr)

n=ceil(vr.totalTrials/(4*vr.numberOfFOVs))*(4*vr.numberOfFOVs);
sequenceOfFOVs=zeros(1, n);

for i=1:vr.totalTrials
    sequenceOfFOVs(i)=mod(floor((i-1)/4), vr.numberOfFOVs);
end
    
end