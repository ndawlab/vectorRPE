function [ trialSequence totalTrials ] = generatePseudorandomTrials( NumTrials )

totalTrials=floor(NumTrials/2)*2;

trialSequence=zeros(1,totalTrials);

n=totalTrials/2;

for i=1:n
    if rand<0.5
        trialSequence([2*(i-1)+1,2*i])=[1 2];
    else
        trialSequence([2*(i-1)+1,2*i])=[2 1];
    end
end

end