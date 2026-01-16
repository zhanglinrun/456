function NFMJ = nfmj(N,t,f,P,k,T,p,start,pass,ts)
    pp = 10^(P/10);
    A = sqrt(pp);
    u = wgn(1,N,p);
    i = 1:1:N;
    ssum = cumsum(u(i))*T/N;
    fi = 2*pi*rand();
    NFMJ = A*exp(1i*(2*pi*f*t+fi+2*pi*k*ssum));
    usignal = ones(1,N);
    nstart = round(abs(start)/ts);
    npass = round(pass/ts);
    if abs(start)+pass >= T
        npass = N-nstart;
    end
    if start < 0
        usignal = [zeros(1,(N-npass-nstart)),ones(1,npass),zeros(1,nstart)];
    elseif start > 0
        usignal = [zeros(1,nstart),ones(1,npass),zeros(1,(N-npass-nstart))];
    end
    NFMJ = NFMJ.*usignal;
end
