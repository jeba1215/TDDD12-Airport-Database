#Enable running the script several times

unlock tables;
drop database if exists tddd12_project;

create database tddd12_project;
use tddd12_project;

# Create all tables without foreign keys

create table Passenger(
	id int primary key auto_increment,
	ticket_nr int,
	booking int
	);

create table Contact(
	id int primary key,
	phone_nr varchar(30),
	email varchar(30)
	);

create table Booking(
	id int primary key auto_increment,
	contact int,
	payment int,
	flight int,
	num_of_passengers int,
    cost int default 0
	);

create table Payment(
	id int primary key auto_increment,
	card_nr varchar(30),
	cvc int
	);

create table Flight(
	id int primary key auto_increment,
    route int,
	day int,
	time time,
	departure date,
	unpaid_seats int not null default 60 
	);

create table Weekly_Flight(
	day int,
	time time,
	route int
	);

create table Route(
	id int primary key auto_increment,
	dest int,
	depart int,
	price int,
	year int
	);

create table City(
	id int primary key auto_increment,
	name varchar(30)
	);

create table Profit(
	year int primary key,
	factor int
	);

create table Day(
	id int,
	year int,
	factor float,
	primary key(id, year)
	);
    
create table Debug(
	id int
);


# Setup foreign keys

alter table Passenger add constraint foreign key(booking) references Booking(id);

alter table Contact add foreign key(id) references Passenger(id);

alter table Booking add foreign key(contact) references Contact(id);
alter table	Booking add foreign key(payment) references Payment(id);
alter table	Booking add foreign key(flight) references Flight(id);

alter table Weekly_Flight add foreign key(route) references Route(id);

alter table Route add foreign key(dest) references City(id);
alter table Route add foreign key(depart) references City(id);

# Insert values

insert into Day(id, year, factor) values(1, 2015, 1);
insert into Day(id, year, factor) values(2, 2015, 1);
insert into Day(id, year, factor) values(3, 2015, 1);
insert into Day(id, year, factor) values(4, 2015, 1);
insert into Day(id, year, factor) values(5, 2015, 4);
insert into Day(id, year, factor) values(6, 2015, 5);
insert into Day(id, year, factor) values(7, 2015, 4);

insert into Day(id, year, factor) values(1, 2016, 1);
insert into Day(id, year, factor) values(2, 2016, 2);
insert into Day(id, year, factor) values(3, 2016, 1);
insert into Day(id, year, factor) values(4, 2016, 2);
insert into Day(id, year, factor) values(5, 2016, 4);
insert into Day(id, year, factor) values(6, 2016, 5);
insert into Day(id, year, factor) values(7, 2016, 4);

insert into Profit(year, factor) values(2015, 2);
insert into Profit(year, factor) values(2016, 3);

insert into City(name) values("Linkoping");
insert into City(name) values("Stockholm");
insert into City(name) values("Jonkoping");
insert into City(name) values("Goteborg");

insert into Route(year, price, depart, dest) values(2015, 2500, 1, 2);
insert into Route(year, price, depart, dest) values(2015, 2500, 2, 1);
insert into Route(year, price, depart, dest) values(2015, 2000, 3, 4);
insert into Route(year, price, depart, dest) values(2015, 3000, 2, 3);

insert into Weekly_Flight(day, time, route) values(4, 150000, 1);
insert into Weekly_Flight(day, time, route) values(4, 160000, 1);
insert into Weekly_Flight(day, time, route) values(2, 090000, 2);
insert into Weekly_Flight(day, time, route) values(6, 101500, 3);
insert into Weekly_Flight(day, time, route) values(7, 203000, 4);

insert into Flight(day, time, route, departure) values(4, 150000, 1, '2015-05-06');
insert into Flight(day, time, route, departure) values(4, 160000, 1, '2015-05-06');
insert into Flight(day, time, route, departure) values(2, 090000, 2, '2015-06-10');
insert into Flight(day, time, route, departure) values(6, 101500, 3, '2015-07-20');
insert into Flight(day, time, route, departure) values(7, 203000, 4, '2015-07-25');

# Create Procedures

delimiter //

create procedure bookFlight(in flight int, in _seats int, out bookingNr int)
begin
	DECLARE specialty CONDITION FOR SQLSTATE '45000';
	if checkSeats(flight) > _seats then
		insert into Booking(flight, num_of_passengers) values(flight, _seats);
		select MAX(id) into bookingNr from Booking;
	else
		signal sqlstate '45000' set message_text = "Failed to book flight - Not enough seats available";
	end if;
end;
//

create procedure addPassenger(in bookingNr int)
begin
	insert into Passenger(booking) values(bookingNr);
    update Booking
		set cost = calcPrice(bookingNr) * passengersInBooking(bookingNr) where booking.id = bookingNr;
end;
//

create procedure addContact(in bookingNr int, in passengerNr int, in phoneNr varchar(30), in _email varchar(30))
begin
	DECLARE specialty CONDITION FOR SQLSTATE '45001';
	if bookingNr in ( select id from Booking) then
		if passengerNr in ( select id from Passenger) then
			insert into Contact(id, phone_nr, email) values(passengerNr, phoneNr, _email);
			update Booking
			set contact = passengerNr
			where id = bookingNr;
		else
			signal sqlstate '45001' set message_text = "Failed to add contat - Contact is not a passenger";
        end if;
	else
		signal sqlstate '45001' set message_text = "Failed to add contact - Booking does not exist";
    end if;
end;
//

create procedure addPayment(in cardNr varchar(30), in cvcNr int, in bookingNr int, in amount int)
begin
	DECLARE specialty CONDITION FOR SQLSTATE '45000';
    if checkSeats((select b1.flight from booking as b1 where b1.id = bookingNr)) > 
					(select b2.num_of_passengers from Booking as b2 where b2.id = bookingNr) then
        
		if bookingNr in ( select b3.id from Booking as b3 ) then
			if bookingNr in (select b4.id from Booking as b4 where b4.contact is not NULL) then
				if calcPrice((select b5.flight from booking as b5 where b5.id = bookingNr)) <= amount then
					insert into Payment(card_nr, cvc) values(cardNr, cvcNr);
                    
					update Booking as b6
						set b6.payment = (select Max(id) from Payment) where b6.id = bookingNr;
				
					update Flight
						set unpaid_seats = (select unpaid_seats - ifnull(( 
												select num_of_passengers from Booking as b7
												where b7.id = bookingNr), 0)
												) where Flight.id = 
                                                (select flight from Booking as b8 where b8.id = bookingNr);
                                                
				else
					signal sqlstate '45000' set message_text = "Payment fail - Payment too low";
				end if;
			else
				signal sqlstate '45000' set message_text = "Payment fail - Contact null";
			end if;
		else
			signal sqlstate '45000' set message_text = "Payment fail - BookingID not in booking table";
		end if;
	else
		signal sqlstate '45002' set message_text = "Payment fail - Not enough unpaid seats on the flight";
	end if;
end;
//

create trigger addTicketNr after update on Booking
for each row 
begin
	if ifnull(new.payment,0) != ifnull(old.payment, 0) then
		update Passenger
			set ticket_nr = RAND() * 10000
			where booking = new.id;
	end if;
end;
//

create function passengersInBooking(_booking int) returns int
begin
	select COUNT(*) from Passenger
    where booking = _booking
    into @ret;
    return @ret;
end
//

create function checkSeats(flight int) returns int
begin
	select unpaid_seats into @avail_seats
    from Flight
    where Flight.id = flight;
    return @avail_seats;
end;
//

create function calcPrice(flight int) returns int
begin
	select (Route.price * Day.factor * (60 - Flight.unpaid_seats + 1)/60 * Profit.factor) as Flightprice
    from Flight
    join Route
    on Route.id = Flight.route
    join Day
    on Day.id = Flight.day
    join Profit
    on Profit.year = 2015
    where Flight.id = flight
    group by Flight
    into @price;
    return @price;
end;
//

create procedure showFlights(in _route int, in _passengers int, _departure date)
begin
	select Flight.*, calcPrice(Flight.id)*_passengers as price, checkSeats(Flight.id) as free_seats from flight
    where departure = _departure and route = _route and checkSeats(Flight.id) > _passengers;
end;
//

# Create a reservation and book a flight
create procedure createReservationBookFlight(in flight int, in passengers int)
begin
    DECLARE a INT Default 0;
    set a = 0;
	
    call bookFlight(flight, passengers, @booking);
    
    _loop: LOOP         
		call addPassenger(@booking);
        SET a = a + 1;
		IF a = passengers THEN
			LEAVE _loop;
		END IF;
	END LOOP _loop;
    
    call addContact(@booking, (select max(id) from passenger), '123123', 'test@test.com');
    call addPayment('123456', '123', @booking, (select calcPrice(flight) from Booking where id = @booking));
end;
//

# Create a reservation and book a flight that's full
create procedure createReservationWhenFull()
begin
	call bookFlight(1, 61, @booking);
end
//

# Search flights with showFlights function
create procedure searchFlights()
begin
	call showFlights(1, 2, '2015-05-06');
end
//

delimiter ;

# Call testfunctions
lock tables flight write, booking write, profit read, day read, route read, passenger write, contact write, booking as b1 read, booking as b2 read, booking as b3 read, booking as b4 read, booking as b5 read, booking as b6 write, payment write, booking as b7 read, booking as b8 read;
call createReservationBookFlight(1, 10);
unlock tables;

#Search for flights
call searchFlights();

#Try to book a flight on a full plane
call createReservationWhenFull();









