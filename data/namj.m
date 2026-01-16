function NAMJ = namj(N,t,f,P,U0,b,start,pass,ts,T)
    p = 10^(P/10);
    A = sqrt(1.4142*p);
    un = wgn(1,N,0);
    fil = fft(fir1(N-1,b));
    un = ifft(fft(un).*fil);
    un = un/sqrt(b*2);
    fi = 2*pi*rand();
    NAMJ = A*(un+U0).*exp(1i*(2*pi*f*t+fi));
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
    NAMJ = NAMJ.*usignal;
end
