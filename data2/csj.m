function CSJ = csj(N,t,JSR,signal,tfr,ts,Nr,tau,mul,B)
    n = randi([5,12]);%
    Bf = (2+1.5*rand)*B;%1e6
    tf = (B-Bf)*rand()/2;
    Bf = Bf/1.1;

    plist = rand(1,n)+1;
    P = 10^(JSR/10);
    plist = plist/sum(plist);
    A = sqrt(P*plist);
    fd = Bf/(n-1);
    f = -Bf/2:fd:Bf/2;
    f = f+tf;
    CSJ = zeros(1,N);
    for i=1:1:n
        CSJ = CSJ+A(i)*exp(1i*(2*pi*f(i)*t)).*signal;%.*signal
    end
%     ntr = round(Tr/ts);
    for i=2:1:Nr
        TTr = 2*tau+mul*rand();
        ntr = round(TTr/ts);
        signal = [zeros(1,ntr),signal(1,1:(N-ntr))];

%         fd = Bf/(n-1);
%         f = -Bf/2:fd:Bf/2;
%         f = f+tf;

        pcsj = zeros(1,N);
        plist = rand(1,n)+1;
        plist = plist/sum(plist);
        A = sqrt(P*plist);
        for j=1:1:n
            pcsj = pcsj+A(j)*exp(1i*(2*pi*f(j)*t)).*signal;
        end
        CSJ = CSJ+pcsj;
    end
    nr = round(tfr/ts);
    CSJ = [zeros(1,nr),CSJ(1,1:(N-nr))];
    [nb,wn] = buttord(0.98,0.99,3,40);
    [b,a] = butter(nb,wn);
    CSJ = filter(b,a,CSJ);
end
