function [ odorSequence, trialSequence, totalTrials ] = generatePseudorandomOdorSequence( NumTrials )

totalTrials=floor(NumTrials/4)*4;

odorSequence=zeros(1,totalTrials);

n=totalTrials/4;

for i=1:n
    switch(mod(floor(rand*10), 4))
        case 0
            odorSequence([4*(i-1)+1,4*(i-1)+2,4*(i-1)+3,4*i])=[1 2 3 4];
        case 1
            odorSequence([4*(i-1)+1,4*(i-1)+2,4*(i-1)+3,4*i])=[2 1 3 4];
        case 2
            odorSequence([4*(i-1)+1,4*(i-1)+2,4*(i-1)+3,4*i])=[1 2 4 3];
        case 3
            odorSequence([4*(i-1)+1,4*(i-1)+2,4*(i-1)+3,4*i])=[2 1 4 3];
    end
end

trialSequence=zeros(1,totalTrials);

for i=1:totalTrials
    if mod(odorSequence(i), 2)
        trialSequence(i)=1;
    else
        trialSequence(i)=2;
    end
end

end