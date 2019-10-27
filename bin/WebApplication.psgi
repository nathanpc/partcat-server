#!/usr/bin/perl

package PartCat::WebApplication;

use strict;
use warnings;

use DBI;
use Dancer2;
use Dancer2::Plugin::REST;
use Config::Tiny;

use User::Account;

# Set the default (de)serializer to JSON.
set serializer => "JSON";

# Stuff required to be done before each request.
hook before => sub {
	# Set the environment variables.
	var config => Config::Tiny->read("config/testing.conf");
	var dbh => DBI->connect("dbi:SQLite:dbname=" . vars->{config}->{database}->{name},
							"", "", { AutoCommit => 1 });
};

# Root path.
get "/" => sub {
	return "It works!";
};

# User handler.
prefix "/user" => sub {
	# List them.
	get "/list" => sub {
		my @user_refs;

		# Check if the user is authenticated.
		check_auth();

		# Grab a user list and create their references.
		my @users = User::Account->list(dbh => vars->{dbh});
		for my $user (@users) {
			push @user_refs, $user->as_hashref(pass_hidden => 1);
		}

		# Return the data.
		return {
			list => \@user_refs,
			count => scalar @user_refs
		};
	};

	# Get a user.
	get "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get user.
		my $user = User::Account->load(dbh => vars->{dbh},
									   id => route_parameters->get("id"));
		if (defined $user) {
			return $user->as_hashref(pass_hidden => 1);
		}

		return status_not_found({ error => "User not found." });
	};

	# Delete a user by its ID.
	del "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get user.
		my $user = User::Account->load(dbh => vars->{dbh},
									   id => route_parameters->get("id"));
		if (defined $user) {
			$user->delete();
			return { message => "User deleted successfully." };
		}

		return status_not_found({ error => "User not found." });
	};

	# Create a user.
	post "/new" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Create user.
		my $user = User::Account->create(vars->{dbh},
										 body_parameters->get("email"),
										 body_parameters->get("password"),
										 7);

		# Check if the user object was able to be created.
		if (defined $user) {
			if ($user->save()) {
				return $user->as_hashref(pass_hidden => 1);
			}
		}

		return status_bad_request({ error => "Some problem occured while trying to create the user. Check your parameters and try again." });
	};
};

# Checks if the user is authenticated.
sub check_auth {
	my $email = request_header("Email");
	my $password = request_header("Password");

	# Check if the headers were defined and check if the user exists.
	if (defined $email and defined $password) {
		my $user = User::Account->load(dbh => vars->{dbh}, email => $email);

		# Check if the user was found and the password matches.
		if (defined $user) {
			if ($user->check_password($password)) {
				return;
			}
		}
	}

	halt(status_unauthorized({ error => "Email and/or password incorrect." }));
}

start;

__END__

=head1 NAME

PartCat::WebApplication - PartCat web application.

=head1 SYNOPSIS

  # Initialize the server.
  $ plackup -r -R lib bin/WebApplication.psgi

=head1 API ENDPOINTS

=over 4

=item C</user/list>

Lists all the users available.

=item C</user/:id>

Get information about a user by its I<id>.

=back

=head1 METHODS

=over 4

=item I<\%err_msg> = C<check_auth>

Checks if the authentication headers were sent and that they match with a stored
user. In case of an error or the user doesn't exist a I<\%err_msg> is returned.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut