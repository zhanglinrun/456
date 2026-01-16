function [Signal,t,t2t,t0,n0,N,usignal,k,ts,nxt,chip] = signal(B,fs,fo,tau,Tr,SP,fi,tr,ext)
    k = B/tau;%调频斜率
    ts = 1/fs;%采样周期
    % t = -ext:ts:(Tr+ext); %以ts为间隔产生Tr/ts个抽样
    t = 0:ts:Tr; %以ts为间隔产生Tr/ts个抽样
    % t2t = -ext:ts:(2*Tr+3*ext+ts);
    t2t = 0:ts:2*Tr+ts;
    t0 = -tau/2:ts:tau/2;%0:ts:tau;%
    n0 = length(t0);
    N = length(t);
    nxt = round(ext/ts);
    p = 10^(SP/10);
    A = sqrt(p);
    usignal = zeros(1,N);%单位脉冲
    n0n = 0;
    for i = 1:1:N
        if t(i) >= tr+t0(1) && t(i) <= tr+t0(n0) %-2*tau/3
            usignal(i) = 1;
            if n0n == 0
                n0n = i;
            end
        end
    end
    Signal = A*exp(1i*(2*pi*fo*(t-tr)+pi*k*(t-tr).^2+fi));
    Signal = usignal.*Signal;
    chip = [Signal(1,n0n:(n0+n0n-1)),zeros(1,N-n0)];
end
