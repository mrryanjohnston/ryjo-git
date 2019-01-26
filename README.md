# ryjo's Git Scripts

## Description

Scripts to help you create, set up, interact with and tear down your very own
git server on AWS. This is a companion repository for my (soon to be series of)
post(s) related to hosting your own git server.
[Give it a read](https://ryjo.codes/articles/hosting-your-own-git-server-part-1.html)
and feel free to use what you find here to better your organization's toolchain.

## Usage

You can initialize the server like so:

```bash
./bin/init-server.sh
```

By default, this script uses opendns to determine your ip address. If you don't
want it to do that, you'll be to otherwise figure out what your IP address is.
This can be easily done by using your favorite search engine to search for "What
is my IP address?" Then, run the following:

```bash
MY_IP=0.0.0.0 ./bin/init-server.sh
```

It may take some time for this command to complete because it waits for the EC2
instance to come up. After it completes, you should be able to issue commands
on the git server like so:

```bash
ssh ubuntu@gitservadmin "whoami"
```

Note that we can do `gitservadmin`. The `init-server.sh` script adds a line to
the `~/.ssh/config` file that lets us do this. Give the `init-server.sh` script
a read to see what other nice things it does for us.

Now that you've got your server set up, we can install the binaries that our
admins and users will run. I've created some pre built binaries you can get
[here](). Either that, or do `debuild --no-tgz-check` to build the `deb`
packages. Copy the `ryjo-git-server_0.0.1_all.deb` file to the server and
install it like so:

```bash
scp ryjo-git-server_0.0.1_all.deb ubuntu@gitservadmin:~
ssh ubuntu@gitservadmin "sudo dpkg -i ryjo-git-server_0.0.1_all.deb"
```

Now we can add a new user to our server like so:

```bash
# The user would run this on their machine:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ryjo
# Then they'd send you their pub file
# which you would use like so:
ssh ubuntu@gitservadmin "addgituser ryjo $(cat ~/.ssh/ryjo.pub)"
# OR if they send you the public key itself:
ssh ubuntu@gitservadmin "addgituser ryjo 'ssh-rsa ...'"
# where "ssh-rsa ..." is the user's key
```

Alternatively, you can install the local client binaries to a place in your
path and run them in a much more convenient way:

```bash
ln -s bin/client/admin/git-adduser /usr/local/bin
git adduser ryjo "$(cat ~/.ssh/ryjo.pub)"
```

There is also a `deb` package available if you're running a debian-based distro
on your client machine that'll install the `git-adduser` binary for you so you
don't have to do the `ln -s` command above:

```bash
dpkg -i ryjo-git-client-admin_0.0.1_all.deb
```

Your new user should add the following to their `$HOME/.ssh/config` file:

```
Host gitserv
    Hostname 0.0.0.0
    IdentityFile ~/.ssh/ryjo_rsa
    IdentitiesOnly yes
```

... where `0.0.0.0` is the ip address of your git server.

Alternatively, if your user is running a debian-based distro on their machine,
they can install the client `deb` file which will add the above placeholder
entry into their `~/.ssh/config` file during installation:

```bash
dpkg -i ryjo-git-client_0.0.1_all.deb
```

This will also install the `git-addrepo` binary on their machine which will let
them add a repo to the git server:

```bash
git addrepo foo
git clone ryjo@gitserv:/srv/git/foo.git
cd foo
echo "# Foo" > README.md
git add .
git commit -m "Initial commit."
git push
```

If they didn't install `ryjo-git-client_0.0.1_all.deb`, they'll need to manually
install `bin/client/user/addrepo` in a directory in their `$PATH` in order to do
the above `git addrepo` command.

## Uninstalling

If you want to undo what was done with `init-server.sh`, you can run:

```bash
./bin/rm-server.sh
```

Note that this does a bunch of destructive stuff, so make sure you read the
contents of that file first before you run it. Awareness is key!
