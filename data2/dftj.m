% N：总信号长度。这个参数确定了生成信号的长度，通常用于表示采样点数。
% 
% JSR：假目标的信干比（Jamming to Signal Ratio），以 dB 为单位。该参数控制了假目标信号相对于真实信号的强度。
% 
% ts：采样时间间隔。该参数定义了信号的时间采样间隔，用于将时域信号离散化。
% 
% chip：原始信号。chip 表示真实信号的一个片段，将用于生成假目标信号。
% 
% tfr：总延迟时间。tfr 定义了假目标信号的初始延迟，相对于原始信号的延迟。
% 
% Nr：假目标的数量。Nr 决定了生成的假目标数量，这些假目标会以不同的延迟和频率偏移相叠加。
% 
% tau：基本延迟。tau 是假目标信号之间的延迟步长，控制着每个假目标信号之间的时间间隔。
% 
% mul：用于控制延迟的一个倍数因子。可以用来调节假目标间延迟的倍率，调整假目标在时间轴上的分布。
% 
% judge：判断因子，用于控制输出信号的选择。judge 用于在最终判断是否应用特定条件（例如，是否在延迟时间 nfr 满足某些条件时裁剪信号）。
% 
% fd：频率偏移数组。fd 是一个向量，包含每个假目标信号的频率偏移量，用于为不同假目标信号添加频率偏移。
% 
% t：时间数组。时间数组用于计算复指数部分，从而实现频率偏移。
function DFTJ = dftj(N,JSR,ts,chip,tfr,Nr,tau,mul,judge,fd,t)

    n = randi([3,10]); %n：随机确定的片段数量，表示一个假目标包含的信号片段数量。
    trans = tau/5;
    Tr = n*trans+tau;
    plist = rand(1,n)+1;
    P = 10^(JSR/10);
    con = n*trans/tau;
    plist = con*plist/sum(plist);
    A = sqrt(P*plist);
    nfr = round(tfr/ts);
    nn = round(trans/ts);
    chip = [chip,zeros(1,N)];
    signal = chip;
    aDFTJ = zeros(1,2*N);
    ndt = 0;
    for i = 1:1:n
        aDFTJ = aDFTJ+A(i)*chip.*exp(1i*2*pi*fd(1)*t);
        chip = [zeros(1,nn),chip(1,1:(2*N-nn))];
    end
    nTr = round(Tr/ts);
    for i = 2:1:Nr
        signal = [zeros(1,nTr),signal(1,1:(2*N-nTr))];
        plist = rand(1,n)+1;
        plist = con*plist/sum(plist);
        A = sqrt(P*plist);
        pdftj = signal;
        for j = 1:1:n
            aDFTJ = aDFTJ+A(j)*pdftj.*exp(1i*2*pi*fd(i)*t);
            pdftj = [zeros(1,nn),pdftj(1,1:(2*N-nn))];
        end

        Tr = n*trans+tau;
        ndt = ndt+nTr+nn*n;
    end
    if rand > judge && nfr < ndt+12
        DFTJ = aDFTJ(1,(nfr+1):(N+nfr));
    else
        DFTJ = [zeros(1,nfr),aDFTJ(1,1:(N-nfr))];
    end
%     pdftj = DFTJ;
%     for i = 2:1:Nr
%         pdftj = [zeros(1,nTr),pdftj(1,1:(N-nTr))];
%         DFTJ = DFTJ+pdftj;
%     end
end
