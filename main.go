package main

import (
	// "context"
	"fmt"

	"tinygo.org/x/bluetooth"
)

var adapter = bluetooth.DefaultAdapter

func main() {
  	// Enable BLE interface.
	must("enable BLE stack", adapter.Enable())
	println("scanning...")
	opts := bluetooth.ConnectionParams{}
	 
	err := adapter.Scan(func(adapter *bluetooth.Adapter, device bluetooth.ScanResult) {
		println("found device:", device.Address.String(), device.RSSI, device.LocalName())
		peripheral, connectionErr := adapter.Connect(device.Address, opts)
		println("connection attempt: ", peripheral.Address.String(), connectionErr.Error())
	})
	fmt.Println(err.Error())
	// ctx, cancel := context.WithCancel(context.Background())
	// adapter.SetConnectHandler(func(device bluetooth.Device, connected bool) {
	// 	if connected {
	// 		println("device connected:", device.Address.String())
	// 		return
	// 	}

	// 	println("device disconnected:", device.Address.String())
	// 	cancel()
	// })

  	// Define the peripheral device info.
	// adv := adapter.DefaultAdvertisement()
	// must("config adv", adv.Configure(bluetooth.AdvertisementOptions{
	// 	LocalName: "Go Bluetooth",
  	// }))
  
  	// // Start advertising
	// must("start adv", adv.Start())
	
	// // Stop advertising to release resources
	// defer adv.Stop()

	// println("advertising...")
	// <- ctx.Done()
}

func must(action string, err error) {
	if err != nil {
		panic("failed to " + action + ": " + err.Error())
	}
}