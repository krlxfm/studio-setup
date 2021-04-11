import sys
import os
import csv
import datetime
import subprocess
import datetime


HOST = 'krlxdj@garnet.krlx.org'
CREDENTIALS = '~/dj_credentials.csv'
TEMPLATE = '~/butt/libretime'
BUTTRC = '/tmp/butt.conf'


def check_remote_file_exists(filename):
    rax = True
    with subprocess.Popen(['ssh', HOST, 'file', filename],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE) as proc:
        output = proc.stdout.read().decode('utf-8')
        if 'No such file or directory' in output:
            rax = False
    return rax


def get_credentials_filename():
    credentials_file = CREDENTIALS
    if len(sys.argv) > 1:
        credentials_file = sys.argv[1]
    if check_remote_file_exists(credentials_file) == False:
        print(f'ERROR:  Cannot find credentials file {credentials_file} on server.', file=sys.stderr)
        print('        Please contact KRLX IT over Slack immediately!\n', file=sys.stderr)
        print('        Press <Enter> to end the program.', file=sys.stderr)
        input()
        sys.exit(1)
    return credentials_file


def find_current_credentials(filename):
    curr_wday = datetime.date.now().weekday()
    curr_time = datetime.time.now()
    login = ''
    password = ''
    with subprocess.Popen(['ssh', HOST, 'cat', filename], stdout=subprocess.PIPE, stderr=subprocess.PIPE) as proc:
        reader = csv.reader(proc.stdout)
        # format is name,startDate,startTime,endDate,endTime,login,password,emails
        for row in reader:
            if len(row) < 7 or 'startDate' == row[1]:
                continue    # skip header, and skip final newline or other misformed rows
            start_wday = datetime.date.fromisoformat(row[1]).weekday()
            start_time = datetime.time(*[int(val) for val in row[2].split(':')])
            end_wday = datetime.date.fromisoformat(row[3]).weekday()
            end_time = datetime.time(*[int(val) for val in row[4].split(':')])
            if (start_wday <= curr_wday <= end_wday) and (start_time <= curr_time <= end_time):
                login = row[5]
                password = row[6]
    if login == '' or password == '':
        print('ERROR:  Could not find a show scheduled for the current time.', file=sys.stderr)
        print('        Please wait to run this program until just after your show begins.\n', file=sys.stderr)
        print('        Press <Enter> to end the program.', file=sys.stderr)
        input()
        sys.exit(2)
    return login, password


def build_buttrc(template, output, login, password):
    if check_remote_file_exists(template) == False:
        print(f'ERROR:  Could not find butt configuration file: {template}', file=sys.stderr)
        print('        Please contact KRLX IT over Slack immediately!\n', file=sys.stderr)
        print('        Press <Enter> to end the program.', file=sys.stderr)
        input()
        sys.exit(3)

    lines = []
    with subprocess.Popen(['ssh', HOST, 'cat', template], stdout=subprocess.PIPE, stderr=subprocess.PIPE) as proc:
        for line in proc.stdout.readlines():
            if 'usr = ' in line:
                line = b'usr = {}'.format(login)
            elif 'password = ' in line:
                line = b'password = {}'.format(password)
            lines.append(bytes(line))
    tmp_name = f'buttrc_{str(datetime.datetime.now().timestamp())}'
    with open(tmp_name, 'w') as outfile:
        outfile.writelines(lines)
    subprocess.Popen(['scp', tmp_name, f'{HOST}:{output}'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    os.remove(tmp_name)


def run_butt():
    subprocess.Popen(
            ['ssh', HOST, 'butt', '-c', BUTTRC],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)


def main():
    credentials_filename = get_credentials_filename()
    login, password = find_current_credentials(credentials_filename)
    build_buttrc(TEMPLATE, BUTTRC, login, password)
    run_butt()  # Could be run by a separate thread, to keep the primary thread available for timing, graphics, etc.
    # monitor_butt()      # The command `butt -S` prints the status of a currently-running butt instance, but seems to fail on Mac
    # Check out https://danielnoethen.de/butt/manual.html for more details (near bottom of page for "Command line options")


if __name__ == '__main__':
    main()
