#!/usr/bin/perl

package Library::Component::Image;

use strict;
use warnings;

use Carp;
use DBI;

# Constructor.
sub new {
	my ($class, $dbh) = @_;
	my $self = {
		_dbh  => $dbh,
		id    => undef,
		name  => undef,
		path  => undef,
		dirty => 1
	};

	bless $self, $class;
	return $self;
}

# Creates a new image.
sub create {
	my ($class, $dbh, $name, $path) = @_;
	my $self = $class->new($dbh);

	# Set name and path correctly.
	$self->{name} = $name;
	if (not $self->set_path($path)) {
		return;
	}

	# Set dirtiness and return the object.
	$self->{dirty} = 1;
	return $self;
}

# Populates the object with data from the database.
sub load {
	my ($class, %lookup) = @_;
	my $self = $class->new($lookup{dbh});

	# Check if we have the ID.
	if (not defined $lookup{id}) {
		carp "No 'id' field found in %lookup";
		return;
	}

	# Fetch image data.
	my $image = $self->_fetch_image($lookup{id});
	if (defined $image) {
		# Populate the object.
		$self->{id} = $image->{id};
		$self->{name} = $image->{name};
		$self->{path} = $image->{path};

		# Set dirtiness and return.
		$self->{dirty} = 0;
		return $self;
	}
}

# Saves the image data to the database.
sub save {
	my ($self) = @_;
	my $success = 0;

	# Check if all the required parameters are defined.
	foreach my $param ("name", "path") {
		if (not defined $self->{$param}) {
			carp "Image '$param' was not defined before saving";
			return 0;
		}
	}

	if (defined $self->{id}) {
		# Update image information.
		$success = $self->_update_image();
		$self->{dirty} = not $success;
	} else {
		# Create a new image.
		my $image_id = $self->_add_image();

		# Check if the image was created successfully.
		if (defined $image_id) {
			$self->{id} = $image_id;
			$self->{dirty} = 0;
			$success = 1;
		}
	}

	return $success;
}

# Get a image object parameter.
sub get {
	my ($self, $param) = @_;

	if (defined $self->{$param}) {
		# Check if it is a private parameter.
		if ($param =~ m/^_.+/) {
			return;
		}

		# Valid and defined parameter.
		return $self->{$param};
	}

	return;
}

# Set the image path.
sub set_path {
	my ($self, $path) = @_;

	if (-s $path) {
		$self->{path} = $path;

		$self->{dirty} = 1;
		return 1;
	}

	return 0;
}

# Check if this image is valid.
sub exists {
	my ($class, %lookup) = @_;
	my $dbh;

	# Check type of call.
	if (not ref $class) {
		# Calling as a static method.
		if (not defined $lookup{dbh}) {
			croak "A database handler wasn't defined";
		}

		$dbh = $lookup{dbh};
	} else {
		# Calling as a object method.
		$dbh = $class->{_dbh};

		# Check for dirtiness.
		if ($class->{dirty}) {
			return 0;
		}
	}

	# Lookup the component by ID.
	if (defined $lookup{id}) {
		my $sth = $lookup{dbh}->prepare("SELECT id FROM Image WHERE id = ?");
		$sth->execute($lookup{id});

		if (defined $sth->fetchrow_arrayref()) {
			return 1;
		}
	}

	# Image wasn't found.
	return 0;
}


# Fetches the image data from the database.
sub _fetch_image {
	my ($self, $id) = @_;

	my $sth = $self->{_dbh}->prepare("SELECT * FROM Images WHERE id = ?");
	$sth->execute($id);

	return $sth->fetchrow_hashref();
}

# Update a image in the database.
sub _update_image {
	my ($self) = @_;

	# Check if image exists.
	if (not Library::Component::Image->exists(dbh => $self->{_dbh},
											  id => $self->{id})) {
		carp "Can't update a image that doesn't exist";
		return 0;
	}

	# Update the image information.
	my $sth = $self->{_dbh}->prepare("UPDATE images SET name = ?, path = ?
                                     WHERE id = ?");
	if ($sth->execute($self->{name}, $self->{path}, $self->{id})) {
		return 1;
	}

	return 0;
}

# Adds a new image to the database.
sub _add_image {
	my ($self) = @_;

	# Check if the image already exists.
	if (defined $self->{id}) {
		carp "Image ID already exists";
		return;
	}

	# Add the new image to the database.
	my $sth = $self->{_dbh}->prepare("INSERT INTO Images(name, path)
                                     VALUES (?, ?)");
	if ($sth->execute($self->{name}, $self->{path})) {
		# Get the image ID from the last insert operation.
		return $self->{_dbh}->last_insert_id(undef, undef, 'images', 'id');
	}
}

1;

__END__

=head1 NAME

Library::Component::Image - Abstraction layer to interact with component images.

=head1 SYNOPSIS

  # Create a database handler.
  my $dbh = DBI->connect(...);

  # Create an empty image object.
  my $image = Library::Component::Image->new($dbh);

  # Load a image.
  my $id = 123;
  $image = Library::Component::Image->new($dbh, $id);
  my $path = $image->get("path");
  $image->save();

=head1 METHODS

=over 4

=item I<$image> = C<Library::Component::Image>->C<new>(I<$dbh>[, I<$id>])

Initializes an empty image object or a populated one if the optional I<$id>
parameter is supplied.

=item I<$image> = C<Library::Component>->C<create>(I<$dbh>, I<name>, I<$path>)

Creates a new image with I<$name> and I<$path> already checked for validity.

=item I<$image> = C<Library::Component::Image>->C<load>(I<%lookup>)

Loads the image object with data from the database given a database handler
(I<dbh>), and a ID (I<id>) in the I<%lookup> argument.

=item I<$status> = I<$image>->C<save>()

Saves the image data to the database. If the operation is successful, this will
return C<1>.

=item I<$data> = I<$image>->C<get>(I<$param>)

Retrieves the value of I<$param> from the image object.

=item I<$success> = I<$image>->C<set_path>(I<$path>)

Sets the image path and returns C<1> if it's valid. B<Remember> to call
C<save()> to commit these changes to the database.

=item I<$valid> = I<$image>->C<exists>(I<%lookup>)

Checks if this image exists and if it is valid and can be used in other objects.
In other words: Has a image ID defined in the database and has not been edited
without being saved.

If called statically the I<%lookup> argument is used to check in the database.
It should contain a I<dbh> parameter and a I<id>.

=back

=head1 PRIVATE METHODS

=item I<\%data> = I<$self>->C<_fetch_image>(I<$id>)

Fetches image data from the database given a image I<id>.

=item I<$success> = I<$self>->C<_update_image>()

Updates the image data in the database with the values from the object and
returns C<1> if the operation was successful.

=item I<$image_id> = I<$self>->C<_add_image>()

Creates a new image inside the database with the values from the object and
returns the component ID if everything went fine.

=over 4

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut