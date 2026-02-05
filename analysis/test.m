clearvars
x = 1:10;

i = 1;
% exitt = true;
while i < 8 & ~exitt
    x(i)
    i = i+ 1;
    if (i > numel(x))
        exitt=true;
        % break
    end
end