function ISFJ = isfj(N,JSR,ts,chip,tfr,n0,Nr,mul,tau,judge,fd,t)
    tr = tau/5;
    Tr = ceil(tau/tr/2)*2*tr;

    plist = rand(1,Nr)+1;
    A = 10^(JSR/20);
    plist = plist/max(plist);
    A = A*sqrt(plist);
    nfr = round(tfr/ts);
    n = round(tr/ts);
    nn = ceil(n0/n/2);
    list = [ones(1,n),zeros(1,n)];
    for i = 2:1:nn
        list = [list,ones(1,n),zeros(1,n)];
    end
    flip = [list(1,1:n0),zeros(1,N-n0)];
    tchip = chip.*flip;
%     pisfj = ISFJ;
    aISFJ = [tchip*A(1),zeros(1,N)].*exp(1i*2*pi*fd(1)*t);
    nTr = 0;
    for i = 2:1:Nr
        nTr = nTr+round(Tr/ts);
        list = [ones(1,n),zeros(1,n)];
        for j = 2:1:nn
            list = [list,ones(1,n),zeros(1,n)];
        end
        flip = [list(1,1:n0),zeros(1,N-n0)];
        tchip = chip.*flip;
        pisfj = [tchip(1,1:n0),zeros(1,2*N-n0)];

        pisfj = [zeros(1,nTr),pisfj(1,1:(2*N-nTr))];
        aISFJ = aISFJ+pisfj*A(i).*exp(1i*2*pi*fd(i)*t);

        Tr = ceil(tau/tr/2)*2*tr;
    end
    if rand > judge && nfr < nTr
        ISFJ = [aISFJ(1,(nfr+1):(N+nfr))];
    else
        ISFJ = [zeros(1,nfr),aISFJ(1,1:(N-nfr))];
    end
end
