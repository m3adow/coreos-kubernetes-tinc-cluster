#!/usr/bin/env python
import CloudFlare
import os
import pprint

from argparse import ArgumentParser
from tld import get_tld


def grab_values():

    myargs = dict()

    for key,value in {
        'email': 'CF_API_EMAIL',
        'token': 'CF_API_KEY',
        'domain': None,
        'ips': None
    }.iteritems():
        myargs[key] = os.environ.get(value)
    parser = ArgumentParser()
    parser.add_argument("-d", "--domain", help="FQDN to change", metavar="DOMAIN", required=True)
    parser.add_argument("-i", "--ips", help="IPs to use (comma-separated)", metavar="ENDPOINTS", required=True)
    parser.add_argument("-e", "--email", help="Cloudflare account E-mail", metavar="EMAIL")
    parser.add_argument("-t", "--token", help="Cloudflare API token", metavar="TOKEN")

    cmdargs = parser.parse_args()
    for arg in vars(cmdargs):
        if getattr(cmdargs,arg):
            myargs[arg] = getattr(cmdargs, arg)

    for key in myargs.keys():
        if myargs[key] is None:
            print("%s required." % key)
            parser.print_help()
            exit(1)

    myargs['ips'] = myargs['ips'].split(',')
    # get_tld expects an URL >__<
    myargs['zone'] = get_tld('http://%s' %myargs['domain'])

    return myargs


def get_dns_records(cf, zone_id, domain):
    return cf.zones.dns_records.get(zone_id, params={'name': domain})


def filter_existing(ips, records):
    new_ips = list(ips)
    new_records = list(records)
    print len(new_ips)
    print len(new_records)

    for record in records:
        if record['content'] in ips:
            new_ips.remove(record['content'])
            new_records.remove(record)

    return new_ips, new_records


def add_new_record(cf,zone_id, domain, ip):
    print("Adding %s" % ip)
    cf.zones.dns_records.post(zone_id, data={
        'name': domain,
        'type': 'A',
        'content': ip,
        'ttl': 120
    })


def update_record(cf,zone_id, domain, ip, record):
    print("Updating %s on %s" % (ip, record))
    cf.zones.dns_records.put(zone_id, record['id'], data={
        'name': domain,
        'type': 'A',
        'content': ip,
        'ttl': 120
    })


def delete_record(cf,zone_id, record):
    print("Deleting %s" % record)
    cf.zones.dns_records.delete(zone_id, record['id'])


def main():
    args = grab_values()
    cf = CloudFlare.CloudFlare(email=args['email'], token=args['token'])
    zone_id = cf.zones.get(params={'name': args['zone']})[0]['id']
    records = get_dns_records(cf, zone_id, args['domain'])

    # Search for existing entries to keep those
    args['ips'], records = filter_existing(args['ips'], records)

    while records or args['ips']:
        # To do as few API calls and DNS Updates as possible, update remaining inactive records
        if records and args['ips']:
            update_record(cf, zone_id, args['domain'],args['ips'][0], records[0])
            args['ips'].pop(0)
            records.pop(0)
        elif records:
            delete_record(cf, zone_id, records[0])
            records.pop(0)
        else:
            add_new_record(cf, zone_id, args['domain'], args['ips'][0])
            args['ips'].pop(0)


if __name__ == '__main__':
    main()
