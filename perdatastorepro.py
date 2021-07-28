#!/usr/bin/python

import gi
gi.require_version("Gtk", "3.0")
gi.require_version('AppIndicator3', '0.1')
import os
from gi.repository import Gtk as gtk, AppIndicator3 as appindicator, GLib as glib

gi.require_version("Notify", "0.7")
from gi.repository import Notify

import subprocess
import signal
import os
import time
import threading

processId = -1
globalX = 0
x=0
#win

class MyWindow(gtk.Window):
    def __init__(self):
        gtk.Window.__init__(self, title="PerDataStoreProj")
        gtk.Window.set_default_size(self, 200, 340)
        
        self.icon = self.render_icon(gtk.STOCK_INDEX, 1)
        self.set_icon(self.icon)
        self.box = gtk.Box(orientation=gtk.Orientation.VERTICAL, spacing=6)
        self.add(self.box)    
            
        self.spinner = gtk.Spinner()
        self.box.pack_start(self.spinner, True, True, 2)
        
        #self.label0 = gtk.Label(label="User0")
        #self.label0.set_halign(gtk.Align.CENTER)
        #self.label0.set_valign(gtk.Align.CENTER)
        #self.label0.set_text('   fgdfg   ')
        #self.box.pack_start(self.label0, True, True, 2)
        
        self.image = gtk.Image()
        self.box.pack_start(self.image, True, True, 2)
        
        self.label = gtk.Label(label="User")
        self.label.set_halign(gtk.Align.CENTER)
        self.label.set_valign(gtk.Align.CENTER)
        self.box.pack_start(self.label, True, True, 2)
        
        self.subbox = gtk.Box(orientation=gtk.Orientation.HORIZONTAL, spacing=6)
        
        self.button = gtk.Button(label="Details")
        self.button.set_halign(gtk.Align.CENTER)
        self.button.set_valign(gtk.Align.CENTER)
        self.button.connect("clicked", self.on_button_clicked)
        
        self.button2 = gtk.Button(label="Errors")
        self.button2.set_halign(gtk.Align.CENTER)
        self.button2.set_valign(gtk.Align.CENTER)
        self.button2.connect("clicked", self.on_button_clicked)
        
        self.subbox.pack_start(self.button, True, True, 0)
        self.subbox.pack_start(self.button2, True, True, 0)
        self.box.pack_start(self.subbox, True, True, 2)  
        self.counter = 10
        self.timeout_id = glib.timeout_add(1000, self.on_timeout, None)

        with open("/home/dungnt/ShellScript/sshsyncapp/.temp/mainlog.txt", "r") as file:
            line = file.readline()
            for line in file:
                pass
        try:
            print("lastline of mainlog.txt:"+line)
        except:
            line = 'go to sleep\n'
        if line == 'go to sleep\n':
            self.spinner.stop()
            self.label.set_text('Finished!')
            self.image.set_from_file("/home/dungnt/Pictures/done.jpg")
        else:
            self.spinner.start()
            self.label.set_text('Syncing....')
            self.image.set_from_file("/home/dungnt/Pictures/anhcungmau.png")

    def on_timeout(self, *args, **kwargs):
        self.counter -= 1
        if self.counter <= 0:
            self.stop_timer("Reached time out")
            return False
        #print("Remaining: " + str(int(self.counter)))
        return True
        
    def stop_timer(self, alabeltext):
        """ Stop the timer. """
        if self.timeout_id:
            #glib.source_remove(self.timeout_id)
            #self.timeout_id = None
            self.counter = 10
            self.timeout_id = glib.timeout_add(1000, self.on_timeout, None)
        
        print(alabeltext)
        with open("/home/dungnt/ShellScript/sshsyncapp/.temp/mainlog.txt", "r") as file:
            line = file.readline()
            for line in file:
                pass
        try:
            print("lastline of mainlog.txt:"+line)
        except:
            line = 'go to sleep\n'
        if line == 'go to sleep\n':
            self.spinner.stop()
            self.label.set_text('Finished!')
            self.image.set_from_file("/home/dungnt/Pictures/done.jpg")
        else:
            self.spinner.start()
            self.label.set_text('Syncing....')
            self.image.set_from_file("/home/dungnt/Pictures/anhcungmau.png")
        
    def on_button_clicked(self, widget):
        #n = Notify.Notification.new("Simple GTK3 Application", "Hello World !!")
        #n.show()
        #win2 = MyWindow()
        #win2.connect("destroy", win)
        #win2.show_all()
        #os.system("cp /home/dungnt/SharedFolder/'Pi pc'/links.txt /home/dungnt")
        #batcmd="/home/dungnt/ShellScript/sshsyncapp/runfrompython.sh"
        #x = subprocess.check_output(batcmd,shell=False)
        #os.spawnl(os.P_NOWAIT, 'bash /home/dungnt/ShellScript/sshsyncapp/sshsyncdir.sh')
        #batcmd="gedit /home/dungnt/hello.txt"
        #subprocess.check_output(batcmd,shell=True)
        os.spawnlp(os.P_NOWAIT, 'gedit', 'gedit', '/home/dungnt/hello.txt')
        #subprocess.run(batcmd)
        #messagebox.showinfo("showinfo", "Start App success")
        
    def on_delete_event(event, self, widget):
        globalX=0
        print(globalX)
        self.hide()
        glib.source_remove(self.timeout_id)
        self.timeout_id = None
		#self.destroy_app()
        return True

def main():
  indicator = appindicator.Indicator.new("customtray", "semi-starred-symbolic", appindicator.IndicatorCategory.APPLICATION_STATUS)
  indicator.set_status(appindicator.IndicatorStatus.ACTIVE)
  indicator.set_menu(menu())
  Notify.init("PerDataStoreProj Application")
  # Create a new notification
  n = Notify.Notification.new("Default Title","Default Body")
  # Update the title / body
  n.update("PerDataStoreProj Application","Started!")
  # Show it
  n.show()
  #run sync
  #os.spawnlp(os.P_WAIT, 'bash', 'bash', '/home/dungnt/ShellScript/sshsyncapp/runfrompython.sh')
  global processId
  processId = subprocess.Popen(["bash", "/home/dungnt/ShellScript/sshsyncapp/sshsyncdir.sh"]).pid
  print('pid '+str(processId))
  

  #os.killpg(os.getpgid(processId), signal.SIGTERM)
  #p = subprocess.Popen("bash /home/dungnt/ShellScript/sshsyncapp/sshsyncdir.sh", stdout=subprocess.PIPE, shell=True)
  #batcmd="pgrep -f /home/dungnt/ShellScript/sshsyncapp/sshsyncdir.sh"
  #x = subprocess.check_output(batcmd,shell=True)
  #x_string = str(x)
  #print(x_string)
  #x_string = x_string.split("\\n")
  #x_string_len=len(x_string)
  #print('x_string_len ',x_string_len)
  #x_string = x_string[0].split("'")
  #global processId
  #processId=x_string[1]
  #print('processId ',processId)
  gtk.main()

  
def menu():
  menu = gtk.Menu()
  
  command_one = gtk.MenuItem(label="Main Menu", use_underline=False)
  command_one.connect('activate', note)
  menu.append(command_one)

  exittray = gtk.MenuItem(label="Exit", use_underline=True)
  exittray.connect('activate', quit)
  menu.append(exittray)
  
  menu.show_all()
  return menu
  
def note(_):
  #os.system("gedit $HOME/Documents/notes.txt")
  #notify()
  win = MyWindow()
  win.connect("delete-event", win.on_delete_event)
  win.show_all()
  globalX=1
  print(globalX)
  
def quit(_):
  
  global processId
  batcmd="kill " + str(processId)
  print(batcmd)
  subprocess.check_output(batcmd,shell=True)
  gtk.main_quit()

if __name__ == "__main__":
  main()
  #while not killer.kill_now:
  #  time.sleep(2)
  #  print("doing something in a loop ...")
  #print("End of the program. I was killed gracefully :)")








	
