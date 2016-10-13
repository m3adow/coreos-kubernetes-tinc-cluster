FROM m3adow/python-cloudflare
MAINTAINER Till Wiese <mail-github.com@till-wiese.de>

RUN pip install tld

COPY ["change-cf-dns.py", "opt/"]

CMD ["python", "/opt/change-cf-dns.py"]