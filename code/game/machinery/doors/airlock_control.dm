#define AIRLOCK_CONTROL_RANGE 22

// This code allows for airlocks to be controlled externally by setting an id_tag and comm frequency (disables ID access)
obj/structure/machinery/door/airlock
	var/id_tag
	var/frequency
	var/shockedby = list()
	var/datum/radio_frequency/radio_connection
	var/cur_command = null	//the command the door is currently attempting to complete
	flags_can_pass_all = NO_FLAGS

obj/structure/machinery/door/airlock/proc/can_radio()
	if(!arePowerSystemsOn())
		return 0
	return 1

obj/structure/machinery/door/airlock/process()
	..()
	if (arePowerSystemsOn())
		execute_current_command()

obj/structure/machinery/door/airlock/receive_signal(datum/signal/signal)
	if (!arePowerSystemsOn()) return //no power

	if (!can_radio()) return //no radio

	if(!signal || signal.encryption) return

	if(id_tag != signal.data["tag"] || !signal.data["command"]) return

	cur_command = signal.data["command"]
	INVOKE_ASYNC(src, .proc/execute_current_command)

obj/structure/machinery/door/airlock/proc/execute_current_command()
	if(operating)
		return //emagged or busy doing something else

	if (!cur_command)
		return

	do_command(cur_command)
	if (command_completed(cur_command))
		cur_command = null

obj/structure/machinery/door/airlock/proc/do_command(var/command)
	switch(command)
		if("open")
			open()

		if("close")
			close()

		if("unlock")
			unlock()

		if("lock")
			lock()

		if("secure_open")
			unlock()

			sleep(2)
			open()

			lock()

		if("secure_close")
			unlock()
			close()

			lock()
			sleep(2)

	send_status()

obj/structure/machinery/door/airlock/proc/command_completed(var/command)
	switch(command)
		if("open")
			return (!density)

		if("close")
			return density

		if("unlock")
			return !locked

		if("lock")
			return locked

		if("secure_open")
			return (locked && !density)

		if("secure_close")
			return (locked && density)

	return 1	//Unknown command. Just assume it's completed.

obj/structure/machinery/door/airlock/proc/send_status(var/bumped = 0)
	if(radio_connection)
		var/datum/signal/signal = new
		signal.transmission_method = 1 //radio signal
		signal.data["tag"] = id_tag
		signal.data["timestamp"] = world.time

		signal.data["door_status"] = density?("closed"):("open")
		signal.data["lock_status"] = locked?("locked"):("unlocked")

		if (bumped)
			signal.data["bumped_with_access"] = 1

		radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)


obj/structure/machinery/door/airlock/open(surpress_send)
	. = ..()
	if(!surpress_send) send_status()


obj/structure/machinery/door/airlock/close(surpress_send)
	. = ..()
	if(!surpress_send) send_status()


obj/structure/machinery/door/airlock/proc/set_frequency(new_frequency)
	radio_controller.remove_object(src, frequency)
	if(new_frequency)
		frequency = new_frequency
		radio_connection = radio_controller.add_object(src, frequency, RADIO_AIRLOCK)


obj/structure/machinery/door/airlock/initialize()
	if(frequency)
		set_frequency(frequency)

	update_icon()


obj/structure/machinery/door/airlock/New()
	..()

	if(radio_controller)
		set_frequency(frequency)

	start_processing()



obj/structure/machinery/airlock_sensor
	icon = 'icons/obj/structures/machinery/airlock_machines.dmi'
	icon_state = "airlock_sensor_off"
	name = "airlock sensor"

	anchored = 1
	power_channel = ENVIRON

	var/id_tag
	var/master_tag
	var/frequency = 1379
	var/command = "cycle"

	var/datum/radio_frequency/radio_connection

	var/on = 1
	var/alert = 0
	var/previousPressure

obj/structure/machinery/airlock_sensor/update_icon()
	if(on)
		if(alert)
			icon_state = "airlock_sensor_alert"
		else
			icon_state = "airlock_sensor_standby"
	else
		icon_state = "airlock_sensor_off"

obj/structure/machinery/airlock_sensor/attack_hand(mob/user)
	var/datum/signal/signal = new
	signal.transmission_method = 1 //radio signal
	signal.data["tag"] = master_tag
	signal.data["command"] = command

	radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)
	flick("airlock_sensor_cycle", src)

obj/structure/machinery/airlock_sensor/process()
	if(on)
		var/air_pressure = return_air()
		var/pressure = round(air_pressure,0.1)

		if(abs(pressure - previousPressure) > 0.001 || previousPressure == null)
			var/datum/signal/signal = new
			signal.transmission_method = 1 //radio signal
			signal.data["tag"] = id_tag
			signal.data["timestamp"] = world.time
			signal.data["pressure"] = num2text(pressure)

			radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)

			previousPressure = pressure

			alert = (pressure < ONE_ATMOSPHERE*0.8)

			update_icon()

obj/structure/machinery/airlock_sensor/proc/set_frequency(new_frequency)
	radio_controller.remove_object(src, frequency)
	frequency = new_frequency
	radio_connection = radio_controller.add_object(src, frequency, RADIO_AIRLOCK)

obj/structure/machinery/airlock_sensor/initialize()
	set_frequency(frequency)

obj/structure/machinery/airlock_sensor/New()
	..()
	if(radio_controller)
		set_frequency(frequency)
	start_processing()


obj/structure/machinery/airlock_sensor/airlock_interior
	command = "cycle_interior"

obj/structure/machinery/airlock_sensor/airlock_exterior
	command = "cycle_exterior"

obj/structure/machinery/access_button
	icon = 'icons/obj/structures/machinery/airlock_machines.dmi'
	icon_state = "access_button_standby"
	name = "access button"

	anchored = 1
	power_channel = ENVIRON

	var/master_tag
	var/frequency = 1449
	var/command = "cycle"

	var/datum/radio_frequency/radio_connection

	var/on = 1


obj/structure/machinery/access_button/update_icon()
	if(on)
		icon_state = "access_button_standby"
	else
		icon_state = "access_button_off"

obj/structure/machinery/access_button/attackby(obj/item/I as obj, mob/user as mob)
	//Swiping ID on the access button
	if (istype(I, /obj/item/card/id))
		attack_hand(user)
		return
	..()

obj/structure/machinery/access_button/attack_hand(mob/user)
	add_fingerprint(usr)
	if(!allowed(user))
		to_chat(user, SPAN_DANGER("Access Denied"))

	else if(radio_connection)
		var/datum/signal/signal = new
		signal.transmission_method = 1 //radio signal
		signal.data["tag"] = master_tag
		signal.data["command"] = command

		radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)
	flick("access_button_cycle", src)


obj/structure/machinery/access_button/proc/set_frequency(new_frequency)
	radio_controller.remove_object(src, frequency)
	frequency = new_frequency
	radio_connection = radio_controller.add_object(src, frequency, RADIO_AIRLOCK)


obj/structure/machinery/access_button/initialize()
	set_frequency(frequency)


obj/structure/machinery/access_button/New()
	..()

	if(radio_controller)
		set_frequency(frequency)

obj/structure/machinery/access_button/airlock_interior
	frequency = 1379
	command = "cycle_interior"

obj/structure/machinery/access_button/airlock_exterior
	frequency = 1379
	command = "cycle_exterior"
