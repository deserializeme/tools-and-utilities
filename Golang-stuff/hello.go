package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

type Band struct {
	Name  string `json:"name"`
	Genre string `json:"genre"`
	ID    int    `json:"id"`
}

var Bands = []Band{}

func MakeNewBand(name string, genre string, id int) *Band {

	//var my_band = Band{Name: name, Genre: genre, ID: id}

	var my_band = Band{}

	my_band.Name = name
	my_band.Genre = genre
	my_band.ID = id

	Bands = append(Bands, my_band)
	return &my_band
}

func add_new_band(w http.ResponseWriter, r *http.Request) {
	reqBody, _ := ioutil.ReadAll(r.Body)

	var new_band Band
	json.Unmarshal(reqBody, &new_band)

	var exists bool = band_exists(new_band)

	if !exists {
		Bands = append(Bands, new_band)
		json.NewEncoder(w).Encode(new_band)
	}
}

func band_exists(my_band Band) bool {
	var found bool = false

	for _, band := range Bands {
		if my_band.Name == band.Name {
			found = true
		}
	}
	return found
}

func find_band(name string) *Band {
	my_band := Band{Name: "Band Not Found", Genre: "Band Not Found", ID: 404}

	for index, band := range Bands {
		if band.Name == name {
			my_band = Bands[index]
		}
	}
	return &my_band
}

func ip_handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Add("Content-Type", "application/json")
	resp, _ := json.Marshal(map[string]string{
		"ip": GetIP(r),
	})
	w.Write(resp)
}

func GetIP(r *http.Request) string {
	forwarded := r.Header.Get("X-FORWARDED-FOR")
	if forwarded != "" {
		return forwarded
	}
	return r.RemoteAddr
}

func return_all_bands(w http.ResponseWriter, r *http.Request) {
	fmt.Println("Endpoint Hit:  return_all_bands")
	json.NewEncoder(w).Encode(Bands)
}

func return_single_band(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["name"]
	my_band := find_band(key)
	json.NewEncoder(w).Encode(my_band)
}

func home_page(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Welcome to the Home Page!")
	fmt.Println("Endpoint Hit: home_page")
}

func handleRequests() {
	// creates a new instance of a mux router
	myRouter := mux.NewRouter().StrictSlash(true)

	// replace http.HandleFunc with myRouter.HandleFunc
	//myRouter.HandleFunc("/", home_page)
	myRouter.HandleFunc("/", ip_handler)
	myRouter.HandleFunc("/bands", return_all_bands)
	myRouter.HandleFunc("/band/{name}", return_single_band)
	myRouter.HandleFunc("/band", add_new_band).Methods("POST")

	// finally, instead of passing in nil, we want
	// to pass in our newly created router as the second
	// argument
	log.Fatal(http.ListenAndServe(":8080", myRouter))
}

func main() {
	MakeNewBand("Goobernetes", "DevOps Metal", 0)
	handleRequests()
}
